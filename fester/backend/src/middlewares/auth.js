const jwt = require('jsonwebtoken');
const createError = require('http-errors');
require('dotenv').config();

// Middleware per verificare il token JWT
const authenticateJWT = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next(createError(401, 'Token di autenticazione mancante o formato non valido'));
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (error) {
    console.error('Errore di autenticazione JWT:', error.message);
    return next(createError(403, 'Token non valido o scaduto'));
  }
};

// Middleware per verificare i ruoli degli utenti
const checkRole = (allowedRoles) => {
  return (req, res, next) => {
    if (!req.user) {
      return next(createError(401, 'Utente non autenticato'));
    }

    if (allowedRoles.includes(req.user.role)) {
      next();
    } else {
      return next(createError(403, 'Non hai i permessi necessari per questa azione'));
    }
  };
};

module.exports = { authenticateJWT, checkRole }; 