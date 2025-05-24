const express = require('express');
const router = express.Router();
const { 
  getEvents, 
  createEvent, 
  getEventById, 
  updateEvent, 
  deleteEvent 
} = require('../controllers/eventController');
const { authenticateJWT } = require('../middlewares/auth');

// Tutte le rotte degli eventi richiedono autenticazione
router.use(authenticateJWT);

// Ottieni tutti gli eventi dell'utente
router.get('/', getEvents);

// Crea un nuovo evento
router.post('/', createEvent);

// Ottieni, aggiorna o elimina un evento specifico
router.get('/:id', getEventById);
router.put('/:id', updateEvent);
router.delete('/:id', deleteEvent);

module.exports = router; 