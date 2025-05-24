const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const createError = require('http-errors');
require('express-async-errors');
require('dotenv').config();

// Importa i middleware
const errorHandler = require('./middlewares/errorHandler');
const { authenticateJWT } = require('./middlewares/auth');

// Importa le rotte
const authRoutes = require('./routes/authRoutes');
const eventRoutes = require('./routes/eventRoutes');
const guestRoutes = require('./routes/guestRoutes');

// Crea l'app Express
const app = express();

// Configurazione CORS più permissiva
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,PATCH,OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, Content-Length, X-Requested-With, Accept');
  
  // Gestisci le richieste OPTIONS
  if (req.method === 'OPTIONS') {
    res.sendStatus(200);
  } else {
    next();
  }
});

// Debug middleware
app.use((req, res, next) => {
  console.log('--------------------');
  console.log('Request URL:', req.url);
  console.log('Request Method:', req.method);
  console.log('Request Headers:', req.headers);
  if (req.body) {
    console.log('Request Body:', JSON.stringify(req.body, null, 2));
  }
  console.log('--------------------');
  next();
});

// Middleware
app.use(morgan('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Rotte API
app.use('/api/auth', authRoutes);
app.use('/api/eventi', eventRoutes);
app.use('/api/ospiti', guestRoutes);

// Rotta di health check
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'Server is running' });
});

// Rotta di test per verificare l'autenticazione
app.get('/api/test', (req, res) => {
  res.status(200).json({
    status: 'ok',
    message: 'API test route is working',
    endpoints: {
      auth: '/api/auth',
      eventi: '/api/eventi',
      ospiti: '/api/ospiti'
    }
  });
});

// Gestione 404
app.use((req, res, next) => {
  next(createError(404, `Endpoint non trovato: ${req.originalUrl}`));
});

// Middleware per la gestione degli errori
app.use(errorHandler);

// Porta del server
const PORT = process.env.PORT || 3000;

// Avvia il server
const server = app.listen(PORT, () => {
  console.log(`Server in ascolto sulla porta ${PORT}`);
});

// Gestione errori del server
server.on('error', (error) => {
  console.error('Server error:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
}); 