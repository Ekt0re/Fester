const createError = require('http-errors');
const { supabaseClient, supabaseAdmin } = require('../config/supabase');

// Ottieni tutti gli eventi dell'utente
const getEvents = async (req, res, next) => {
  try {
    const userId = req.user.id;

    // Ottieni eventi creati dall'utente
    const { data: eventsCreated, error: errorCreated } = await supabaseClient
      .from('events')
      .select(`
        id, 
        nome, 
        luogo, 
        data_ora, 
        stato, 
        created_at
      `)
      .eq('creato_da', userId);

    if (errorCreated) {
      return next(createError(500, errorCreated.message));
    }

    // Ottieni eventi a cui l'utente partecipa come staff
    const { data: eventsStaff, error: errorStaff } = await supabaseClient
      .from('event_users')
      .select(`
        events (
          id, 
          nome, 
          luogo, 
          data_ora, 
          stato, 
          created_at
        )
      `)
      .eq('user_id', userId);

    if (errorStaff) {
      return next(createError(500, errorStaff.message));
    }

    // Formatta i risultati
    const staffEvents = eventsStaff.map(item => ({
      ...item.events,
      ruolo: 'staff'
    }));

    const ownedEvents = eventsCreated.map(event => ({
      ...event,
      ruolo: 'owner'
    }));

    // Combina e ordina gli eventi
    const allEvents = [...ownedEvents, ...staffEvents].sort((a, b) => 
      new Date(b.data_ora) - new Date(a.data_ora)
    );

    res.status(200).json({
      success: true,
      data: allEvents
    });
  } catch (error) {
    next(error);
  }
};

// Crea un nuovo evento
const createEvent = async (req, res, next) => {
  try {
    const { nome, luogo, data_ora, regole } = req.body;
    const userId = req.user.id;

    // Inserisci l'evento nel database
    const { data: event, error } = await supabaseClient
      .from('events')
      .insert({
        nome,
        luogo,
        data_ora,
        regole,
        creato_da: userId,
        stato: 'attivo'
      })
      .select()
      .single();

    if (error) {
      return next(createError(400, error.message));
    }

    res.status(201).json({
      success: true,
      data: event
    });
  } catch (error) {
    next(error);
  }
};

// Ottieni dettagli di un evento specifico
const getEventById = async (req, res, next) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    // Controlla se l'utente ha accesso all'evento
    const { data: eventAccess, error: accessError } = await supabaseClient
      .from('events')
      .select('id, creato_da')
      .eq('id', id)
      .single();

    if (accessError) {
      return next(createError(404, 'Evento non trovato'));
    }

    if (eventAccess.creato_da !== userId) {
      // Se non è il creatore, controlla se è staff
      const { data: staffAccess, error: staffError } = await supabaseClient
        .from('event_users')
        .select('id')
        .eq('event_id', id)
        .eq('user_id', userId)
        .single();

      if (staffError || !staffAccess) {
        return next(createError(403, 'Non hai accesso a questo evento'));
      }
    }

    // Ottieni i dettagli completi dell'evento
    const { data: event, error: eventError } = await supabaseClient
      .from('events')
      .select('*')
      .eq('id', id)
      .single();

    if (eventError) {
      return next(createError(404, 'Evento non trovato'));
    }

    // Statistiche base dell'evento
    const { data: guestStats, error: statsError } = await supabaseClient
      .from('guests')
      .select('stato')
      .eq('event_id', id);

    if (statsError) {
      return next(createError(500, statsError.message));
    }

    // Calcola statistiche
    const stats = {
      totale: guestStats.length,
      invitati: guestStats.filter(g => g.stato === 'invitato').length,
      confermati: guestStats.filter(g => g.stato === 'confermato').length,
      presenti: guestStats.filter(g => g.stato === 'presente').length
    };

    res.status(200).json({
      success: true,
      data: {
        ...event,
        stats
      }
    });
  } catch (error) {
    next(error);
  }
};

// Aggiorna un evento
const updateEvent = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { nome, luogo, data_ora, regole, stato } = req.body;
    const userId = req.user.id;

    // Verifica che l'utente sia il proprietario dell'evento
    const { data: event, error: eventError } = await supabaseClient
      .from('events')
      .select('creato_da')
      .eq('id', id)
      .single();

    if (eventError) {
      return next(createError(404, 'Evento non trovato'));
    }

    if (event.creato_da !== userId) {
      return next(createError(403, 'Solo il creatore può modificare l\'evento'));
    }

    // Aggiorna l'evento
    const { data: updatedEvent, error } = await supabaseClient
      .from('events')
      .update({
        nome,
        luogo,
        data_ora,
        regole,
        stato
      })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      return next(createError(400, error.message));
    }

    res.status(200).json({
      success: true,
      data: updatedEvent
    });
  } catch (error) {
    next(error);
  }
};

// Elimina un evento
const deleteEvent = async (req, res, next) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    // Verifica che l'utente sia il proprietario dell'evento
    const { data: event, error: eventError } = await supabaseClient
      .from('events')
      .select('creato_da')
      .eq('id', id)
      .single();

    if (eventError) {
      return next(createError(404, 'Evento non trovato'));
    }

    if (event.creato_da !== userId) {
      return next(createError(403, 'Solo il creatore può eliminare l\'evento'));
    }

    // Aggiorna lo stato invece di eliminare fisicamente
    const { error } = await supabaseClient
      .from('events')
      .update({ stato: 'eliminato' })
      .eq('id', id);

    if (error) {
      return next(createError(400, error.message));
    }

    res.status(200).json({
      success: true,
      message: 'Evento eliminato con successo'
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getEvents,
  createEvent,
  getEventById,
  updateEvent,
  deleteEvent
}; 