// Test de charge de la pré-production avec k6 (https://k6.io).
//
// Simule des apprenants et un formateur qui parcourent la plateforme en même temps :
// profil, blocs, modules, cours et recherche. Les comptes sont ceux créés par
// demo/seed.mjs.
//
// Lancement sans rien installer, depuis ce dépôt :
//   docker run --rm -i --network host -e BASE_URL=http://localhost grafana/k6:1.0.0 run - < loadtest/browse.js
//
// Variables :
//   BASE_URL       adresse de l'interface, nginx compris (http://localhost par défaut)
//   DEMO_PASSWORD  mot de passe des comptes de démonstration
//   VUS            nombre d'utilisateurs simultanés au palier (20 par défaut)
//
// La connexion n'a lieu qu'une fois par compte, dans setup(). Le backend limite les
// connexions à 20 par minute et par adresse IP : se connecter à chaque itération
// mesurerait la limitation et non l'application.
import http from 'k6/http'
import {check, group, sleep} from 'k6'

const BASE_URL = (__ENV.BASE_URL || 'http://localhost').replace(/\/$/, '')
const API = `${BASE_URL}/api/v1`
const PASSWORD = __ENV.DEMO_PASSWORD || 'Butterfly-Demo2026'
const VUS = Number(__ENV.VUS || 20)

const ACCOUNTS = [
    'lucas.bernard@butterfly.local',
    'emma.petit@butterfly.local',
    'sophie.laurent@butterfly.local'
]

// Un 403 est une réponse normale ici. La liste des contenus est relevée avec un
// apprenant et un formateur ne voit que ses propres blocs. Seuls les autres
// codes d'erreur comptent comme des échecs dans http_req_failed.
http.setResponseCallback(http.expectedStatuses(200, 403))

const SEARCH_TERMS = ['java', 'sql', 'git', 'spring', 'php', 'laravel', 'requête', 'classe']

export const options = {
    stages: [
        {duration: '30s', target: VUS},
        {duration: '2m', target: VUS},
        {duration: '20s', target: 0}
    ],
    // Seuils d'acceptation : le test échoue si l'un d'eux est dépassé.
    thresholds: {
        http_req_failed: ['rate<0.01'],
        http_req_duration: ['p(95)<500'],
        'http_req_duration{name:search}': ['p(95)<800']
    }
}

function authHeaders(token) {
    return {headers: {Authorization: `Bearer ${token}`}}
}

function login(email) {
    const res = http.post(`${API}/auth/login`, JSON.stringify({email, password: PASSWORD}),
        {headers: {'Content-Type': 'application/json'}})
    if (res.status !== 200) {
        throw new Error(`Connexion refusée pour ${email} (HTTP ${res.status}). Le seed a-t-il été lancé ?`)
    }
    return res.json('data.accessToken')
}

/**
 * Relève une fois les identifiants à parcourir avec le premier compte apprenant.
 * Les itérations ne demandent ainsi que des contenus qui existent.
 */
function collectContent(token) {
    const blocks = http.get(`${API}/blocks?size=50`, authHeaders(token)).json('data.content') || []
    const moduleIds = []
    const courseIds = []
    for (const block of blocks) {
        const modules = http.get(`${API}/modules/block/${block.id}?size=50`, authHeaders(token)).json('data.content') || []
        for (const module of modules) {
            moduleIds.push(module.id)
            // La liste des modules ne porte pas leurs cours : ils sont demandés à part.
            const courses = http.get(`${API}/courses/module/${module.id}?size=50`, authHeaders(token)).json('data.content') || []
            courseIds.push(...courses.map((c) => c.id))
        }
    }
    return {blockIds: blocks.map((b) => b.id), moduleIds, courseIds}
}

export function setup() {
    const tokens = ACCOUNTS.map(login)
    const content = collectContent(tokens[0])
    if (content.moduleIds.length === 0) {
        throw new Error('Aucun module visible par le compte apprenant : vérifier le seed.')
    }
    return {tokens, ...content}
}

function pick(list) {
    return list[Math.floor(Math.random() * list.length)]
}

export default function (data) {
    // Chaque utilisateur virtuel garde le même compte pendant tout le test.
    const token = data.tokens[(__VU - 1) % data.tokens.length]
    const params = authHeaders(token)

    group('parcours', () => {
        const responses = http.batch([
            ['GET', `${API}/profile`, null, {...params, tags: {name: 'profile'}}],
            ['GET', `${API}/blocks`, null, {...params, tags: {name: 'blocks'}}]
        ])
        check(responses[0], {'profil 200': (r) => r.status === 200})

        if (data.blockIds.length > 0) {
            const block = http.get(`${API}/blocks/${pick(data.blockIds)}`, {...params, tags: {name: 'block'}})
            check(block, {'bloc 200 ou 403': (r) => r.status === 200 || r.status === 403})
        }

        const module = http.get(`${API}/modules/${pick(data.moduleIds)}`, {...params, tags: {name: 'module'}})
        check(module, {'module 200 ou 403': (r) => r.status === 200 || r.status === 403})

        if (data.courseIds.length > 0) {
            const course = http.get(`${API}/courses/${pick(data.courseIds)}`, {...params, tags: {name: 'course'}})
            check(course, {'cours 200 ou 403': (r) => r.status === 200 || r.status === 403})
        }
    })

    // Temps de lecture simulé entre deux pages.
    sleep(1 + Math.random() * 2)

    group('recherche', () => {
        const q = encodeURIComponent(pick(SEARCH_TERMS))
        const res = http.get(`${API}/search?q=${q}`, {...params, tags: {name: 'search'}})
        check(res, {'recherche 200': (r) => r.status === 200})
    })

    sleep(1 + Math.random() * 2)
}
