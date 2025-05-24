const express = require('express');
const router = express.Router();
const { 
  getGuests, 
  addGuest, 
  importGuests, 
  updateGuestStatus, 
  validateQr 
} = require('../controllers/guestController');
const { authenticateJWT } = require('../middlewares/auth');

// Tutte le rotte richiedono autenticazione
router.use(authenticateJWT);

// Ottieni tutti gli ospiti di un evento
router.get('/events/:eventId/guests', getGuests);

// Aggiungi un nuovo ospite a un evento
router.post('/events/:eventId/guests', addGuest);

// Importa ospiti in blocco
router.post('/events/:eventId/guests/import', importGuests);

// Aggiorna lo stato di un ospite
router.put('/events/:eventId/guests/:guestId', updateGuestStatus);

// Valida QR e aggiorna stato (check-in)
router.post('/events/:eventId/checkin', validateQr);

module.exports = router; 