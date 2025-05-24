const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const createError = require('http-errors');
require('express-async-errors');
require('dotenv').config();

// Importa i middleware
const errorHandler = require('./middlewares/errorHandler');

// Importa le rotte
const authRoutes = require('./routes/authRoutes');
const eventRoutes = require('./routes/eventRoutes');
const guestRoutes = require('./routes/guestRoutes');

// Crea l'app Express
const app = express();

// Middleware
app.use(cors());
app.use(helmet());
app.use(morgan('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Rotte API
app.use('/api/auth', authRoutes);
app.use('/api/events', eventRoutes);
app.use('/api', guestRoutes);

// Rotta di health check
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'Server operativo' });
});

// Gestione 404
app.use((req, res, next) => {
  next(createError(404, 'Endpoint non trovato'));
});

// Middleware per la gestione degli errori
app.use(errorHandler);

// Porta del server
const PORT = process.env.PORT || 5000;

// Avvia il server
app.listen(PORT, () => {
  console.log(`Server in esecuzione sulla porta ${PORT}`);
}); 