const crypto = require('crypto');

// Secret key from settings
const SECRET_KEY = 'x-ui-jwt-secret-key-change-this-in-production';

// Create JWT token manually (simple version for testing)
function createJWT(payload, secret) {
    const header = {
        alg: 'HS256',
        typ: 'JWT'
    };
    
    const encodedHeader = Buffer.from(JSON.stringify(header)).toString('base64url');
    const encodedPayload = Buffer.from(JSON.stringify(payload)).toString('base64url');
    
    const signature = crypto
        .createHmac('sha256', secret)
        .update(`${encodedHeader}.${encodedPayload}`)
        .digest('base64url');
    
    return `${encodedHeader}.${encodedPayload}.${signature}`;
}

// Create payload with expiration (24 hours from now)
const now = Math.floor(Date.now() / 1000);
const exp = now + (24 * 60 * 60); // 24 hours

const payload = {
    sub: 'user123',
    iat: now,
    exp: exp
};

// Generate token
const token = createJWT(payload, SECRET_KEY);

console.log('JWT Token:', token);
console.log('\nExpires at:', new Date(exp * 1000).toISOString());
console.log('Expires in: 24 hours');

// Example VLESS link
console.log('\nExample VLESS link:');
console.log(`vless://uuid@server:port?path=/?token=${token}&security=none&encryption=none&host=example.com&type=ws`);

