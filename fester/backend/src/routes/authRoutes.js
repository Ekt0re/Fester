const express = require('express');
const router = express.Router();
const { register, login, getProfile } = require('../controllers/authController');
const { authenticateJWT } = require('../middlewares/auth');

// Rotta per la registrazione
router.post('/register', register);

// Rotta per il login
router.post('/login', login);

// Rotta per ottenere il profilo dell'utente autenticato
router.get('/me', authenticateJWT, getProfile);

module.exports = router; 