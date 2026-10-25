// Chargement des contenus de démonstration dans une instance Butterfly.
//
// Le script passe par l'API REST et non par la base : chaque contenu subit donc les mêmes
// validations qu'une saisie dans l'interface (longueurs, cohérence des quiz, cycles de
// prérequis) et les options de quiz sont mélangées à l'insertion comme le fait le backend.
//
// Utilisation depuis la racine du dépôt de déploiement, la pile étant démarrée :
//   node --env-file=.env demo/seed.mjs
//
// Le script peut être relancé : un compte ou un bloc qui existe déjà est conservé tel quel.

import {readdir, readFile} from 'node:fs/promises'
import path from 'node:path'
import {fileURLToPath} from 'node:url'

const CONTENT_DIR = path.join(path.dirname(fileURLToPath(import.meta.url)), 'content')

// Adresses vues depuis la machine hôte. Elles reprennent les ports du .env de la pile.
// DEMO_API_URL désigne la racine /api. La version est ajoutée ici : elle décrit le contrat
// que ce script sait appeler et ne dépend pas de l'environnement.
const API_ROOT = process.env.DEMO_API_URL ?? `http://localhost:${process.env.FRONTEND_PORT ?? 80}/api`
const API_VERSION = 'v1'
const API_URL = `${API_ROOT.replace(/\/$/, '')}/${API_VERSION}`
const MAILPIT_URL = process.env.DEMO_MAILPIT_URL ?? `http://localhost:${process.env.MAILPIT_UI_PORT ?? 8025}`

// Mot de passe commun aux comptes de démonstration. Il respecte la règle du backend :
// 10 caractères minimum avec majuscule, minuscule, chiffre et caractère spécial.
// Pas de # : node --env-file le prendrait pour le début d'un commentaire.
const DEMO_PASSWORD = process.env.DEMO_PASSWORD ?? 'Butterfly-Demo2026'

const DEMO_USERS = [
    {firstName: 'Sophie', lastName: 'Laurent', email: 'sophie.laurent@butterfly.local', role: 'TEACHER'},
    {firstName: 'Lucas', lastName: 'Bernard', email: 'lucas.bernard@butterfly.local', role: 'USER'},
    {firstName: 'Emma', lastName: 'Petit', email: 'emma.petit@butterfly.local', role: 'USER'}
]

// Objets des messages lus dans Mailpit. Ils doivent suivre ceux du backend :
// EmailVerificationServiceImpl pour la confirmation, AccountInvitationServiceImpl pour
// l'invitation envoyée à un compte créé par l'administrateur.
const VERIFICATION_SUBJECT = 'Confirmez votre adresse e-mail'
const INVITATION_SUBJECT = 'Activez votre compte'
const MAIL_POLL_ATTEMPTS = 15
const MAIL_POLL_DELAY_MS = 1000
const PAGE_SIZE = 100

let accessToken = null

class ApiError extends Error {
    constructor(status, payload, route) {
        const details = payload?.validationErrors
            ? ' ' + JSON.stringify(payload.validationErrors)
            : ''
        super(`${route} a répondu ${status} : ${payload?.message ?? 'réponse sans message'}${details}`)
        this.status = status
    }
}

/**
 * Appelle l'API et renvoie le champ data de l'enveloppe ApiResponse.
 */
async function api(method, route, body) {
    const headers = {'Content-Type': 'application/json'}
    if (accessToken) {
        headers.Authorization = `Bearer ${accessToken}`
    }

    const response = await fetch(API_URL + route, {
        method,
        headers,
        body: body === undefined ? undefined : JSON.stringify(body)
    })
    const payload = await response.json().catch(() => null)

    if (!response.ok) {
        throw new ApiError(response.status, payload, `${method} ${route}`)
    }
    return payload?.data
}

/**
 * Parcourt toutes les pages d'une liste paginée.
 */
async function fetchAllPages(route) {
    const separator = route.includes('?') ? '&' : '?'
    const items = []
    let page = 0
    let last = false

    while (!last) {
        const result = await api('GET', `${route}${separator}page=${page}&size=${PAGE_SIZE}`)
        items.push(...result.content)
        last = result.last
        page++
    }
    return items
}

async function login() {
    const email = process.env.ADMIN_EMAIL
    const password = process.env.ADMIN_PASSWORD
    if (!email || !password) {
        throw new Error('ADMIN_EMAIL et ADMIN_PASSWORD sont requis. Lancez le script avec node --env-file=.env demo/seed.mjs')
    }

    let auth
    try {
        auth = await api('POST', '/auth/login', {email, password})
    } catch (error) {
        if (error.status === 401) {
            // node --env-file coupe une valeur sans guillemets au premier #, Docker Compose non.
            throw new Error('Connexion administrateur refusée. Si ADMIN_PASSWORD contient un #, '
                + 'entourez sa valeur de guillemets dans .env : Docker Compose les retire aussi.')
        }
        throw error
    }
    accessToken = auth.accessToken
    console.log(`Connecté en tant que ${auth.email}`)
}

// ---------------------------------------------------------------------------
// Comptes de démonstration
// ---------------------------------------------------------------------------

async function findUserByEmail(email) {
    const users = await api('GET', `/users?search=${encodeURIComponent(email)}&size=${PAGE_SIZE}`)
    return users.content.find((user) => user.email === email) ?? null
}

/**
 * Crée le compte s'il n'existe pas encore, puis l'active ou confirme son adresse.
 *
 * Depuis le backend v3.1.0, un compte créé par l'administrateur n'a pas de mot de passe :
 * il reçoit une invitation et c'est en l'acceptant que le mot de passe est choisi.
 *
 * @returns {Promise<object>} le compte tel que renvoyé par l'API
 */
async function ensureUser(demoUser) {
    let user = await findUserByEmail(demoUser.email)
    const created = user === null

    if (created) {
        user = await api('POST', '/users', demoUser)
        console.log(`Compte créé : ${user.email} (${user.role})`)
    } else {
        console.log(`Compte existant conservé : ${user.email}`)
    }

    if (user.pendingActivation) {
        await activateAccount(user, created)
    } else if (!user.emailVerified) {
        // Compte créé par une version antérieure, qui avait déjà un mot de passe.
        await verifyEmail(user.email, created)
    }
    return user
}

/**
 * Active un compte invité en suivant le vrai parcours : le lien d'invitation est lu dans
 * Mailpit puis son jeton est présenté à l'API avec le mot de passe de démonstration.
 */
async function activateAccount(user, justCreated) {
    const requestedAt = new Date()

    // Un compte déjà existant n'a peut-être plus de lien valide : on en redemande un.
    if (!justCreated) {
        await api('POST', `/users/${user.id}/invitation`)
    }

    const token = await waitForToken(user.email, INVITATION_SUBJECT, requestedAt)
    if (!token) {
        console.warn(`  Compte non activé pour ${user.email} : aucune invitation trouvée dans Mailpit (${MAILPIT_URL}).`)
        console.warn('  Relancez le script une fois Mailpit joignable.')
        return
    }

    await api('POST', '/auth/activate-account', {
        token,
        newPassword: DEMO_PASSWORD,
        confirmPassword: DEMO_PASSWORD
    })
    console.log(`  Compte activé : ${user.email}`)
}

/**
 * Confirme une adresse en suivant le vrai parcours : le lien est lu dans Mailpit puis son
 * jeton est présenté à l'API comme le ferait l'interface.
 */
async function verifyEmail(email, justCreated) {
    const requestedAt = new Date()

    // Un compte déjà existant n'a peut-être plus de message exploitable : on en redemande un.
    if (!justCreated) {
        await api('POST', '/auth/resend-verification', {email})
    }

    const token = await waitForToken(email, VERIFICATION_SUBJECT, requestedAt)
    if (!token) {
        console.warn(`  Adresse non confirmée pour ${email} : aucun message trouvé dans Mailpit (${MAILPIT_URL}).`)
        console.warn('  Le compte reste utilisable pendant le délai de grâce. Relancez le script une fois Mailpit joignable.')
        return
    }

    await api('POST', '/auth/verify-email', {token})
    console.log(`  Adresse confirmée : ${email}`)
}

/**
 * Attend un message portant un jeton dans Mailpit. L'envoi est asynchrone et part après la
 * validation de la transaction : le message arrive quelques instants après la réponse.
 * Seul un message reçu après la demande compte, un ancien jeton ayant pu être consommé.
 */
async function waitForToken(email, subject, notBefore) {
    const query = encodeURIComponent(`to:"${email}" subject:"${subject}"`)

    for (let attempt = 0; attempt < MAIL_POLL_ATTEMPTS; attempt++) {
        const token = await readLatestToken(query, notBefore)
        if (token) {
            return token
        }
        await new Promise((resolve) => setTimeout(resolve, MAIL_POLL_DELAY_MS))
    }
    return null
}

async function readLatestToken(query, notBefore) {
    try {
        const search = await fetchJson(`${MAILPIT_URL}/api/v1/search?query=${query}&limit=1`)
        const latest = search.messages?.[0]
        // Marge d'une seconde : les horloges de Mailpit et de ce script ne sont pas synchronisées.
        if (!latest || new Date(latest.Created) < new Date(notBefore.getTime() - 1000)) {
            return null
        }
        const message = await fetchJson(`${MAILPIT_URL}/api/v1/message/${latest.ID}`)
        const match = `${message.Text ?? ''} ${message.HTML ?? ''}`.match(/token=([A-Za-z0-9_-]+)/)
        return match ? match[1] : null
    } catch {
        // Mailpit injoignable : le compte reste non confirmé, l'appelant le signale.
        return null
    }
}

async function fetchJson(url) {
    const response = await fetch(url)
    if (!response.ok) {
        throw new Error(`${url} a répondu ${response.status}`)
    }
    return response.json()
}

// ---------------------------------------------------------------------------
// Contenus pédagogiques
// ---------------------------------------------------------------------------

/**
 * Lit les dossiers de contenu dans l'ordre de leur préfixe numérique. Un bloc doit être
 * placé après ses prérequis puisqu'il les désigne par leur nom.
 * <p>
 * Tous les fichiers sont lus avant le premier appel à l'API : un fichier manquant ou un
 * JSON invalide arrête le script avant qu'un bloc ne soit créé à moitié.
 */
async function loadBlockDefinitions() {
    const entries = await readdir(CONTENT_DIR, {withFileTypes: true})
    const folders = entries
        .filter((entry) => entry.isDirectory())
        .map((entry) => entry.name)
        .sort()

    const blocks = []
    for (const folder of folders) {
        const directory = path.join(CONTENT_DIR, folder)
        const block = await readJson(path.join(directory, 'block.json'))

        for (const module of block.modules) {
            for (const item of module.content) {
                item.content = await readFile(path.join(directory, item.file), 'utf8')
            }
            // Même format que l'import de questions de l'interface.
            module.quiz.questions = (await readJson(path.join(directory, module.quiz.file))).questions
        }
        blocks.push(block)
    }
    return blocks
}

async function readJson(file) {
    try {
        return JSON.parse(await readFile(file, 'utf8'))
    } catch (error) {
        throw new Error(`Lecture impossible de ${path.relative(CONTENT_DIR, file)} : ${error.message}`)
    }
}

/**
 * Crée un bloc complet : ses modules, leur contenu dans l'ordre déclaré et leurs quiz.
 * Chaque module a pour prérequis le module qui le précède.
 */
async function createBlock(block, blockIdsByName) {
    const created = await api('POST', '/blocks', {name: block.name, description: block.description})
    console.log(`Bloc créé : ${block.name}`)

    const prerequisiteIds = block.prerequisites.map((name) => {
        const id = blockIdsByName.get(name)
        if (id === undefined) {
            throw new Error(`Le bloc prérequis "${name}" de "${block.name}" est introuvable`)
        }
        return id
    })
    if (prerequisiteIds.length > 0) {
        await api('PUT', `/blocks/${created.id}/prerequisites`, {prerequisiteIds})
    }

    let previousModuleId = null
    for (const module of block.modules) {
        const moduleId = await createModule(module, created.id)
        if (previousModuleId !== null) {
            await api('PUT', `/modules/${moduleId}/prerequisites`, {prerequisiteIds: [previousModuleId]})
        }
        previousModuleId = moduleId
    }
    return created.id
}

async function createModule(module, blockId) {
    const created = await api('POST', '/modules', {
        name: module.name,
        description: module.description,
        blockId
    })

    // Cours et exercices partagent la même suite de positions : le backend place chaque
    // nouvel élément en fin de module, l'ordre de création fixe donc l'ordre du parcours.
    for (const item of module.content) {
        if (item.type === 'course') {
            await api('POST', '/courses', {
                name: item.name,
                description: item.description,
                content: item.content,
                moduleId: created.id
            })
        } else {
            await api('POST', '/exercises', {name: item.name, content: item.content, moduleId: created.id})
        }
    }

    await createQuiz(module.quiz, created.id)
    console.log(`  Module créé : ${module.name}`)
    return created.id
}

async function createQuiz(quiz, moduleId) {
    const quizCreated = await api('POST', '/quizzes', {
        name: quiz.name,
        content: quiz.instructions,
        moduleId,
        shuffleQuestions: quiz.shuffleQuestions,
        shuffleOptions: quiz.shuffleOptions,
        feedbackMode: quiz.feedbackMode,
        showCorrectionOnPass: quiz.showCorrectionOnPass,
        retryCooldownMinutes: quiz.retryCooldownMinutes
    })
    await api('PUT', `/quizzes/${quizCreated.id}/questions`, {questions: quiz.questions})
}

/**
 * Ajoute les blocs de démonstration aux blocs déjà assignés à chaque compte. L'API remplace
 * la liste entière : on repart donc des blocs actuels pour ne rien retirer.
 */
async function assignBlocks(users, blockIds) {
    for (const user of users) {
        const current = await api('GET', `/users/${user.id}`)
        const merged = new Set([...(current.blocks ?? []).map((block) => block.id), ...blockIds])
        await api('PUT', `/users/${user.id}/blocks`, {blockIds: [...merged]})
        console.log(`Blocs assignés à ${user.email} : ${merged.size}`)
    }
}

// ---------------------------------------------------------------------------
// Point d'entrée
// ---------------------------------------------------------------------------

async function main() {
    const blocks = await loadBlockDefinitions()
    console.log(`API : ${API_URL}`)
    await login()

    const users = []
    for (const demoUser of DEMO_USERS) {
        users.push(await ensureUser(demoUser))
    }

    const existingBlocks = await fetchAllPages('/blocks')
    const blockIdsByName = new Map(existingBlocks.map((block) => [block.name, block.id]))

    const demoBlockIds = []
    for (const block of blocks) {
        if (blockIdsByName.has(block.name)) {
            console.log(`Bloc existant conservé : ${block.name}`)
        } else {
            blockIdsByName.set(block.name, await createBlock(block, blockIdsByName))
        }
        demoBlockIds.push(blockIdsByName.get(block.name))
    }

    await assignBlocks(users, demoBlockIds)

    console.log('\nDémonstration prête. Comptes disponibles, mot de passe commun : ' + DEMO_PASSWORD)
    for (const user of DEMO_USERS) {
        console.log(`  ${user.role === 'TEACHER' ? 'Formateur' : 'Apprenant'} : ${user.email}`)
    }
}

main().catch((error) => {
    console.error(`\nÉchec du chargement : ${error.message}`)
    console.error('Un bloc créé en partie est ignoré à la relance : videz-le puis supprimez-le depuis l\'interface avant de relancer.')
    process.exitCode = 1
})
