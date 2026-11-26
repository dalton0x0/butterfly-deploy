// Activité de démonstration : progression, rendus, corrections, quiz et badges.
//
// Rejoue par l'API ce que feraient de vrais apprenants et leur formateur : cours terminés,
// exercices rendus puis corrigés, quiz passés (et parfois ratés puis retentés). Le backend
// calcule lui-même l'expérience, les badges, la complétion des modules et le déverrouillage
// des blocs : rien n'est écrit en base directement.
//
// Chargé par seed.mjs quand DEMO_ACTIVITY=true. Les apprenants doivent pouvoir se connecter :
// leurs comptes sont activés par seed.mjs avant l'appel.
//
// Toute l'activité est datée du moment du chargement : l'API n'accepte pas de date passée.
// Les séries de jours consécutifs démarrent donc à un jour.

// Apprenants ajoutés aux comptes de seed.mjs dans ce mode : plus de profils rendent les
// listes, la file de correction et les tableaux de bord plus parlants.
export const ACTIVITY_LEARNERS = [
    {firstName: 'Hugo', lastName: 'Martin', email: 'hugo.martin@butterfly.local', role: 'USER'},
    {firstName: 'Léa', lastName: 'Dubois', email: 'lea.dubois@butterfly.local', role: 'USER'},
    {firstName: 'Nathan', lastName: 'Roux', email: 'nathan.roux@butterfly.local', role: 'USER'},
    {firstName: 'Chloé', lastName: 'Fournier', email: 'chloe.fournier@butterfly.local', role: 'USER'}
]

const PROMOTION_NAME = 'Promotion de démonstration'

// Parcours de chaque apprenant, bloc par bloc et dans l'ordre des prérequis.
//
// - grades : fourchette des notes attribuées par le formateur, sur 20.
// - modules : nombre de modules terminés en entier ('all' pour tout le bloc).
// - next : état du module suivant, laissé en cours :
//     {courses: n}  les n premiers cours terminés,
//     'pending'     premier exercice rendu, en attente de correction,
//     'rejected'    premier exercice rendu puis refusé, à reprendre.
// - quizRetry : le quiz du premier module est raté une fois avant d'être réussi.
// - reworkFirstExercise : le premier exercice est refusé, rendu à nouveau puis validé.
//
// Chloé Fournier n'a aucun parcours : une inscrite qui n'a pas encore commencé.
const SCENARIOS = new Map([
    ['lucas.bernard@butterfly.local', {
        grades: [16, 19],
        plans: [
            {block: 'Git', modules: 'all'},
            {block: 'SQL et bases de données', modules: 'all'},
            {block: 'Java', modules: 'all'},
            {block: 'Spring Boot', modules: 0, next: 'pending'}
        ]
    }],
    ['emma.petit@butterfly.local', {
        grades: [12, 16],
        plans: [
            {block: 'Git', modules: 'all', quizRetry: true},
            {block: 'PHP', modules: 'all', reworkFirstExercise: true},
            {block: 'SQL et bases de données', modules: 2, next: 'rejected'}
        ]
    }],
    ['hugo.martin@butterfly.local', {
        grades: [10, 14],
        plans: [
            {block: 'Git', modules: 1, next: 'pending', quizRetry: true}
        ]
    }],
    ['lea.dubois@butterfly.local', {
        grades: [14, 18],
        plans: [
            {block: 'Git', modules: 'all'},
            {block: 'Java', modules: 1, next: {courses: 2}}
        ]
    }],
    ['nathan.roux@butterfly.local', {
        grades: [10, 13],
        plans: [
            {block: 'Git', modules: 0, next: {courses: 2}}
        ]
    }]
])

const VALIDATION_FEEDBACK = [
    'Travail propre et bien organisé, la démarche est claire.',
    'Bon rendu. Quelques noms de variables gagneraient à être plus explicites.',
    'Très bien, les cas limites sont traités. Continuez ainsi.',
    'Objectif atteint. Pensez à commenter les choix moins évidents.'
]

const REJECTION_FEEDBACK = 'Le rendu est incomplet : relisez l\'énoncé, il manque la dernière partie. '
    + 'Reprenez-le et renvoyez-le, vous y êtes presque.'

/**
 * Joue l'activité de démonstration.
 *
 * @param ctx.api appel JSON de l'API (méthode, route, corps, options)
 * @param ctx.apiMultipart envoi multipart à l'API (route, formulaire, options)
 * @param ctx.loginAs ouvre une session et renvoie son jeton d'accès
 * @param ctx.users comptes de démonstration, avec leur identifiant
 * @param ctx.blockIdsByName identifiants des blocs, par nom
 * @param ctx.password mot de passe commun des comptes de démonstration
 */
export async function runActivity(ctx) {
    const teacher = ctx.users.find((user) => user.role === 'TEACHER')
    const learners = ctx.users.filter((user) => user.role === 'USER')

    await assignPromotion(ctx, learners)

    const teacherToken = await ctx.loginAs(teacher.email, ctx.password)
    const structure = new BlockStructure(ctx)

    for (const learner of learners) {
        const scenario = SCENARIOS.get(learner.email)
        if (!scenario) {
            console.log(`  ${learner.email} : aucune activité, apprenant qui n'a pas commencé`)
            continue
        }

        const token = await ctx.loginAs(learner.email, ctx.password)
        if (await hasProgress(ctx, token)) {
            console.log(`  ${learner.email} : progression déjà présente, activité ignorée`)
            continue
        }

        const player = new LearnerPlayer(ctx, structure, learner, token, teacherToken, scenario.grades)
        for (const plan of scenario.plans) {
            await player.play(plan)
        }
        console.log(`  ${learner.email} : ${scenario.plans.map((plan) => plan.block).join(', ')}`)
    }
}

/**
 * Rattache les apprenants à une promotion en cours, créée au besoin.
 */
async function assignPromotion(ctx, learners) {
    const promotions = await ctx.api('GET', '/promos?size=100')
    let promotion = promotions.content.find((promo) => promo.name === PROMOTION_NAME)

    if (!promotion) {
        // Dates calées sur le jour du chargement : la promotion est toujours en cours.
        const today = new Date()
        const start = new Date(today.getFullYear(), today.getMonth() - 2, 1)
        const end = new Date(today.getFullYear() + 1, today.getMonth() - 2, 0)
        promotion = await ctx.api('POST', '/promos', {
            name: PROMOTION_NAME,
            startDate: isoDate(start),
            endDate: isoDate(end)
        })
        console.log(`Promotion créée : ${PROMOTION_NAME}`)
    }

    for (const learner of learners) {
        await ctx.api('PATCH', `/users/${learner.id}/promotion/${promotion.id}`)
    }
}

/**
 * Date au format ISO (AAAA-MM-JJ) dans le fuseau local, sans passer par l'UTC.
 */
function isoDate(date) {
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    return `${date.getFullYear()}-${month}-${day}`
}

/**
 * Un apprenant qui a déjà terminé un cours a déjà été joué : relancer le script ne doit
 * pas rendre ses exercices une seconde fois.
 */
async function hasProgress(ctx, token) {
    const courses = await ctx.api('GET', '/progress/courses?size=1', undefined, {token})
    return courses.totalElements > 0
}

/**
 * Structure des blocs lue une fois par l'API, avec l'administrateur : modules dans l'ordre,
 * contenu de chaque module dans l'ordre du parcours, bonnes réponses des quiz.
 */
class BlockStructure {

    constructor(ctx) {
        this.ctx = ctx
        this.modulesByBlock = new Map()
        this.answersByQuiz = new Map()
    }

    async modules(blockName) {
        if (!this.modulesByBlock.has(blockName)) {
            const blockId = this.ctx.blockIdsByName.get(blockName)
            if (blockId === undefined) {
                throw new Error(`Bloc "${blockName}" introuvable pour l'activité de démonstration`)
            }
            const page = await this.ctx.api('GET', `/modules/block/${blockId}?size=100`)
            const modules = []
            for (const summary of [...page.content].sort(byPosition)) {
                const module = await this.ctx.api('GET', `/modules/${summary.id}`)
                // Cours et exercices partagent la même suite de positions.
                const items = [
                    ...(module.courses ?? []).map((course) => ({type: 'course', ...course})),
                    ...(module.exercises ?? []).map((exercise) => ({type: 'exercise', ...exercise}))
                ].sort(byPosition)
                modules.push({id: module.id, items, quiz: module.quiz ?? null})
            }
            this.modulesByBlock.set(blockName, modules)
        }
        return this.modulesByBlock.get(blockName)
    }

    /**
     * Bonnes réponses d'un quiz, par question : lues par l'administrateur, qui seul les voit.
     */
    async answers(quizId) {
        if (!this.answersByQuiz.has(quizId)) {
            const questions = await this.ctx.api('GET', `/quizzes/${quizId}/questions`)
            this.answersByQuiz.set(quizId, new Map(questions.map((question) => [question.id, {
                points: question.points,
                correct: question.options.filter((option) => option.correct).map((option) => option.id),
                wrong: question.options.filter((option) => !option.correct).map((option) => option.id)
            }])))
        }
        return this.answersByQuiz.get(quizId)
    }
}

function byPosition(a, b) {
    return (a.position ?? 0) - (b.position ?? 0)
}

/**
 * Joue le parcours d'un apprenant. Les corrections sont faites par le formateur, avec sa
 * propre session : elles apparaissent à son nom.
 */
class LearnerPlayer {

    constructor(ctx, structure, learner, token, teacherToken, grades) {
        this.ctx = ctx
        this.structure = structure
        this.learner = learner
        this.token = token
        this.teacherToken = teacherToken
        this.grades = grades
        this.gradeIndex = 0
    }

    async play(plan) {
        const modules = await this.structure.modules(plan.block)
        const completed = plan.modules === 'all' ? modules.length : plan.modules

        for (let index = 0; index < completed; index++) {
            await this.completeModule(modules[index], {
                quizRetry: plan.quizRetry && index === 0,
                reworkFirstExercise: plan.reworkFirstExercise && index === 0
            })
        }
        if (plan.next && completed < modules.length) {
            await this.startModule(modules[completed], plan.next)
        }
    }

    async completeModule(module, {quizRetry, reworkFirstExercise}) {
        let firstExercise = true
        for (const item of module.items) {
            if (item.type === 'course') {
                await this.completeCourse(item)
            } else {
                await this.submit(item)
                if (reworkFirstExercise && firstExercise) {
                    await this.reject(item)
                    await this.submit(item, 'Version corrigée après le retour du formateur.')
                }
                await this.validate(item)
                firstExercise = false
            }
        }
        if (module.quiz) {
            if (quizRetry) {
                await this.playQuiz(module.quiz.id, false)
            }
            await this.playQuiz(module.quiz.id, true)
        }
    }

    /**
     * Laisse un module en cours : quelques cours terminés, ou le premier exercice rendu et
     * en attente de correction, ou rendu puis refusé.
     */
    async startModule(module, next) {
        let coursesLeft = typeof next === 'object' ? next.courses : Infinity
        for (const item of module.items) {
            if (item.type === 'course') {
                if (coursesLeft === 0) {
                    return
                }
                await this.completeCourse(item)
                coursesLeft--
            } else {
                if (next === 'pending' || next === 'rejected') {
                    await this.submit(item)
                }
                if (next === 'rejected') {
                    await this.reject(item)
                }
                return
            }
        }
    }

    async completeCourse(course) {
        await this.ctx.api('POST', `/progress/courses/${course.id}/complete`, undefined, {token: this.token})
    }

    async submit(exercise, note = 'Voici mon rendu.') {
        const content = `${note}\n\nRendu de ${this.learner.firstName} ${this.learner.lastName} `
            + `pour l'exercice « ${exercise.name} ».`
        const form = new FormData()
        form.append('data', new Blob([JSON.stringify({content: note})], {type: 'application/json'}))
        form.append('files', new Blob([content], {type: 'text/plain'}), 'rendu.txt')
        await this.ctx.apiMultipart(`/progress/exercises/${exercise.id}/submissions`, form, {token: this.token})
    }

    async validate(exercise) {
        const index = this.gradeIndex++
        const [low, high] = this.grades
        await this.ctx.api('POST', `/progress/exercises/${exercise.id}/users/${this.learner.id}/validate`, {
            grade: low + (index % (high - low + 1)),
            feedback: VALIDATION_FEEDBACK[index % VALIDATION_FEEDBACK.length]
        }, {token: this.teacherToken})
    }

    async reject(exercise) {
        await this.ctx.api('POST', `/progress/exercises/${exercise.id}/users/${this.learner.id}/reject`, {
            grade: this.grades[0] - 4,
            feedback: REJECTION_FEEDBACK
        }, {token: this.teacherToken})
    }

    /**
     * Passe un quiz question par question, comme l'interface.
     * <p>
     * Réussi : toutes les bonnes réponses, sauf une question manquée par un apprenant qui
     * n'a pas le meilleur profil, si le seuil reste atteint. Raté : une mauvaise réponse
     * partout.
     */
    async playQuiz(quizId, pass) {
        const options = {token: this.token}
        const answers = await this.structure.answers(quizId)
        const intro = await this.ctx.api('GET', `/progress/quizzes/${quizId}/intro`, undefined, options)
        const missed = pass && this.grades[1] < 18 ? questionToMiss(answers, intro.passThresholdPercent) : null

        const started = await this.ctx.api('POST', `/progress/quizzes/${quizId}/start`, undefined, options)
        let state = started.state
        while (state.question && !state.completed) {
            const question = state.question
            const expected = answers.get(question.id)
            const answerCorrectly = pass && question.id !== missed
            state = await this.ctx.api('POST', `/progress/attempts/${started.attemptId}/answers`, {
                questionId: question.id,
                selectedOptionIds: answerCorrectly ? expected.correct : [expected.wrong[0]]
            }, options)
        }

        const result = await this.ctx.api('POST', `/progress/attempts/${started.attemptId}/finish`, undefined, options)
        if (result.passed !== pass) {
            throw new Error(`Quiz ${quizId} : résultat inattendu pour ${this.learner.email} `
                + `(${result.score}/${result.maxScore})`)
        }
    }
}

/**
 * Question la moins notée, à manquer si le score reste au-dessus du seuil de réussite.
 */
function questionToMiss(answers, thresholdPercent) {
    const total = [...answers.values()].reduce((sum, answer) => sum + answer.points, 0)
    const [questionId, smallest] = [...answers.entries()]
        .sort(([, a], [, b]) => a.points - b.points)[0]
    return (total - smallest.points) * 100 >= thresholdPercent * total ? questionId : null
}
