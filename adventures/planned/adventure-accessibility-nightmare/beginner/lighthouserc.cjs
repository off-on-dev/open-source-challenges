module.exports = {
    ci: {
        collect: {
            startServerCommand: 'npm run dev -- --host 127.0.0.1',
            startServerReadyPattern: 'Local:',
            url: ['http://127.0.0.1:5173/'],
            numberOfRuns: 1,
        },
        assert: {
            assertions: {
                'categories:accessibility': ['error', { minScore: 0.95 }],
            },
        },
        upload: {
            target: 'filesystem',
            outputDir: './.lighthouseci',
        },
    },
};