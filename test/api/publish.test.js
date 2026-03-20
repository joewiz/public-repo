import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

const BASE_URL = process.env.PUBLIC_REPO_URL || 'http://localhost:8080/exist/apps/public-repo';

describe('/publish endpoint', () => {
    it('should return 403 for unauthenticated upload', async () => {
        const formData = new FormData();
        const blob = new Blob(['fake-xar-content'], { type: 'application/octet-stream' });
        formData.append('files[]', blob, 'test.xar');

        const res = await fetch(`${BASE_URL}/publish`, {
            method: 'POST',
            body: formData
        });
        assert.equal(res.status, 403);
    });

    it('should return JSON error for unauthenticated upload', async () => {
        const formData = new FormData();
        const blob = new Blob(['fake-xar-content'], { type: 'application/octet-stream' });
        formData.append('files[]', blob, 'test.xar');

        const res = await fetch(`${BASE_URL}/publish`, {
            method: 'POST',
            body: formData
        });
        assert.equal(res.status, 403);
        const body = await res.json();
        assert.ok(body.error, 'Expected error field in JSON response');
        assert.ok(body.error.includes('repo'), 'Expected error message to mention repo group');
    });

    it('should not allow GET requests to publish endpoint', async () => {
        const res = await fetch(`${BASE_URL}/publish`);
        // Should redirect to login or return error, not 200
        assert.notEqual(res.status, 200);
    });
});
