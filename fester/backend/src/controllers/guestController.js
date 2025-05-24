const createError = require('http-errors');
const { v4: uuidv4 } = require('uuid');
const { supabaseClient, supabaseAdmin } = require('../config/supabase');

// Ottieni tutti gli ospiti di un evento
const getGuests = async (req, res, next) => {
  try {
    const { eventId } = req.params;
    const userId = req.user.id;

    // Verifica accesso all'evento
    const hasAccess = await checkEventAccess(eventId, userId);
    if (!hasAccess) {
      return next(createError(403, 'Non hai accesso a questo evento'));
    }

    // Ottieni la lista degli ospiti
    const { data: guests, error } = await supabaseClient
      .from('guests')
      .select('*')
      .eq('event_id', eventId)
      .order('cognome', { ascending: true });

    if (error) {
      return next(createError(500, error.message));
    }

    res.status(200).json({
      success: true,
      data: guests
    });
  } catch (error) {
    next(error);
  }
};

// Aggiungi un nuovo ospite
const addGuest = async (req, res, next) => {
  try {
    const { eventId } = req.params;
    const userId = req.user.id;
    const { 
      nome, cognome, email, telefono, data_nascita,
      indirizzo, codice_fiscale, scuola, classe, note 
    } = req.body;

    // Verifica accesso all'evento
    const hasAccess = await checkEventAccess(eventId, userId);
    if (!hasAccess) {
      return next(createError(403, 'Non hai accesso a questo evento'));
    }

    // Genera un codice QR univoco
    const qrCode = uuidv4();

    // Inserisci l'ospite
    const { data: guest, error } = await supabaseClient
      .from('guests')
      .insert({
        event_id: eventId,
        nome,
        cognome,
        email,
        telefono,
        data_nascita,
        indirizzo,
        codice_fiscale,
        scuola,
        classe,
        invitato_da: userId,
        codice_qr: qrCode,
        stato: 'invitato',
        note,
        ordini: []
      })
      .select()
      .single();

    if (error) {
      return next(createError(400, error.message));
    }

    res.status(201).json({
      success: true,
      data: guest
    });
  } catch (error) {
    next(error);
  }
};

// Importa ospiti in blocco
const importGuests = async (req, res, next) => {
  try {
    const { eventId } = req.params;
    const userId = req.user.id;
    const { guests } = req.body;

    // Verifica accesso all'evento
    const hasAccess = await checkEventAccess(eventId, userId);
    if (!hasAccess) {
      return next(createError(403, 'Non hai accesso a questo evento'));
    }

    if (!Array.isArray(guests) || guests.length === 0) {
      return next(createError(400, 'Formato dati non valido'));
    }

    // Prepara gli ospiti da importare
    const guestsToImport = guests.map(guest => ({
      event_id: eventId,
      nome: guest.nome,
      cognome: guest.cognome,
      email: guest.email || null,
      telefono: guest.telefono || null,
      data_nascita: guest.data_nascita,
      indirizzo: guest.indirizzo || null,
      codice_fiscale: guest.codice_fiscale || null,
      scuola: guest.scuola,
      classe: guest.classe,
      invitato_da: userId,
      codice_qr: uuidv4(),
      stato: 'invitato',
      note: guest.note || null,
      ordini: []
    }));

    // Inserisci gli ospiti
    const { data, error } = await supabaseClient
      .from('guests')
      .insert(guestsToImport)
      .select();

    if (error) {
      return next(createError(400, error.message));
    }

    res.status(201).json({
      success: true,
      data: {
        imported: data.length,
        guests: data
      }
    });
  } catch (error) {
    next(error);
  }
};

// Aggiorna lo stato di un ospite
const updateGuestStatus = async (req, res, next) => {
  try {
    const { eventId, guestId } = req.params;
    const { stato, note } = req.body;
    const userId = req.user.id;

    // Verifica accesso all'evento
    const hasAccess = await checkEventAccess(eventId, userId);
    if (!hasAccess) {
      return next(createError(403, 'Non hai accesso a questo evento'));
    }

    // Verifica che l'ospite esista e sia associato all'evento
    const { data: guest, error: guestError } = await supabaseClient
      .from('guests')
      .select('id, stato')
      .eq('id', guestId)
      .eq('event_id', eventId)
      .single();

    if (guestError || !guest) {
      return next(createError(404, 'Ospite non trovato'));
    }

    // Aggiorna lo stato dell'ospite
    const { data: updatedGuest, error } = await supabaseClient
      .from('guests')
      .update({ 
        stato,
        note: note || guest.note
      })
      .eq('id', guestId)
      .select()
      .single();

    if (error) {
      return next(createError(400, error.message));
    }

    res.status(200).json({
      success: true,
      data: updatedGuest
    });
  } catch (error) {
    next(error);
  }
};

// Valida QR e aggiorna stato (check-in)
const validateQr = async (req, res, next) => {
  try {
    const { eventId } = req.params;
    const { qrCode } = req.body;
    const userId = req.user.id;

    // Verifica accesso all'evento
    const hasAccess = await checkEventAccess(eventId, userId);
    if (!hasAccess) {
      return next(createError(403, 'Non hai accesso a questo evento'));
    }

    // Cerca l'ospite tramite QR
    const { data: guest, error: guestError } = await supabaseClient
      .from('guests')
      .select('*')
      .eq('codice_qr', qrCode)
      .eq('event_id', eventId)
      .single();

    if (guestError || !guest) {
      return next(createError(404, 'Codice QR non valido o ospite non trovato'));
    }

    // Aggiorna lo stato a 'presente'
    const { data: updatedGuest, error } = await supabaseClient
      .from('guests')
      .update({ stato: 'presente' })
      .eq('id', guest.id)
      .select()
      .single();

    if (error) {
      return next(createError(400, error.message));
    }

    res.status(200).json({
      success: true,
      data: updatedGuest
    });
  } catch (error) {
    next(error);
  }
};

// Funzione helper per verificare l'accesso a un evento
const checkEventAccess = async (eventId, userId) => {
  // Controlla se l'utente è il proprietario
  const { data: event } = await supabaseClient
    .from('events')
    .select('creato_da')
    .eq('id', eventId)
    .single();

  if (event && event.creato_da === userId) {
    return true;
  }

  // Controlla se l'utente è staff
  const { data: staff } = await supabaseClient
    .from('event_users')
    .select('id')
    .eq('event_id', eventId)
    .eq('user_id', userId)
    .single();

  return !!staff;
};

module.exports = {
  getGuests,
  addGuest,
  importGuests,
  updateGuestStatus,
  validateQr
}; 