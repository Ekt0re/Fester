const createError = require('http-errors');
const { supabaseClient, supabaseAdmin } = require('../config/supabase');

// Ottieni tutti gli eventi dell'utente
const getEvents = async (req, res, next) => {
  try {
    const userId = req.user.id;

    // Prima otteniamo le righe di event_users dell'utente corrente
    const { data: userEvents, error: userEventsError } = await supabaseClient
      .from('event_users')
      .select('event_id, ruolo')
      .eq('auth_user_id', userId);

    if (userEventsError) {
      return next(createError(500, userEventsError.message));
    }

    // Ottieni eventi secondo le policy:
    // - eventi attivi
    // - eventi creati dall'utente
    // - eventi dove l'utente è partecipante
    const { data: events, error: eventsError } = await supabaseClient
      .from('events')
      .select(`
        id, 
        name, 
        place, 
        date_time,
        rules, 
        state, 
        created_by,
        created_at
      `)
      .or(`state.eq.active,created_by.eq.${userId},id.in.(${userEvents.map(ue => ue.event_id).join(',')})`);

    if (eventsError) {
      return next(createError(500, eventsError.message));
    }

    // Aggiungi il ruolo dell'utente per ogni evento
    const eventsWithRole = events.map(event => {
      let ruolo = 'guest';
      if (event.created_by === userId) {
        ruolo = 'organizer';
      } else {
        const userEvent = userEvents.find(ue => ue.event_id === event.id);
        if (userEvent) {
          ruolo = userEvent.ruolo;
        }
      }
      return { ...event, ruolo };
    });

    // Ordina per data
    const sortedEvents = eventsWithRole.sort((a, b) => 
      new Date(b.date_time) - new Date(a.date_time)
    );

    res.status(200).json({
      success: true,
      data: sortedEvents
    });
  } catch (error) {
    next(error);
  }
};

// Crea un nuovo evento
const createEvent = async (req, res, next) => {
  try {
    const { name, place, date_time, rules } = req.body;
    const userId = req.user.id;

    // Validazione del formato della data
    try {
      const parsedDate = new Date(date_time);
      if (isNaN(parsedDate.getTime())) {
        return next(createError(400, 'Formato data non valido. Usa il formato ISO8601'));
      }
    } catch (e) {
      return next(createError(400, 'Formato data non valido. Usa il formato ISO8601'));
    }

    // Inserisci l'evento nel database
    const { data: event, error } = await supabaseClient
      .from('events')
      .insert({
        name,
        place,
        date_time,
        rules: rules || [],
        created_by: userId,
        state: 'draft'  // Stato iniziale draft
      })
      .select()
      .single();

    if (error) {
      return next(createError(400, error.message));
    }

    // Crea il record event_users per l'organizzatore
    const { error: eventUserError } = await supabaseClient
      .from('event_users')
      .insert({
        event_id: event.id,
        auth_user_id: userId,
        role: 'organizer'  // Corretto da ruolo a role
      });

    if (eventUserError) {
      // Se fallisce la creazione dell'event_user, elimina l'evento
      await supabaseClient
        .from('events')
        .delete()
        .eq('id', event.id);
      
      return next(createError(400, eventUserError.message));
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

    // Verifica accesso secondo le policy
    const { data: event, error: eventError } = await supabaseClient
      .from('events')
      .select('*')
      .eq('id', id)
      .single();

    if (eventError) {
      return next(createError(404, 'Evento non trovato'));
    }

    // Verifica se l'utente è un partecipante
    const { data: eventUser, error: eventUserError } = await supabaseClient
      .from('event_users')
      .select('ruolo')
      .eq('event_id', id)
      .eq('auth_user_id', userId)
      .single();

    // Verifica le policy di accesso
    const canAccess = 
      event.state === 'active' ||
      event.created_by === userId ||
      eventUser !== null;

    if (!canAccess) {
      return next(createError(403, 'Non hai accesso a questo evento'));
    }

    // Statistiche base dell'evento
    const { data: guestStats, error: statsError } = await supabaseClient
      .from('guests')
      .select('state')
      .eq('event_id', id);

    if (statsError) {
      return next(createError(500, statsError.message));
    }

    // Calcola statistiche
    const stats = {
      total: guestStats.length,
      invited: guestStats.filter(g => g.state === 'invited').length,
      confirmed: guestStats.filter(g => g.state === 'confirmed').length,
      present: guestStats.filter(g => g.state === 'present').length
    };

    // Aggiungi il ruolo dell'utente
    const ruolo = event.created_by === userId ? 'organizer' : (eventUser?.ruolo || 'guest');

    res.status(200).json({
      success: true,
      data: {
        ...event,
        ruolo,
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
    const { name, place, date_time, rules, state } = req.body;
    const userId = req.user.id;

    // Verifica che l'utente sia il proprietario dell'evento
    const { data: eventUser, error: eventUserError } = await supabaseClient
      .from('event_users')
      .select('role')  // Corretto da ruolo a role
      .eq('event_id', id)
      .eq('auth_user_id', userId)
      .single();

    if (eventUserError || !eventUser || eventUser.role !== 'organizer') {
      return next(createError(403, 'Solo l\'organizzatore può modificare l\'evento'));
    }

    // Aggiorna l'evento
    const { data: updatedEvent, error } = await supabaseClient
      .from('events')
      .update({
        name,
        place,
        date_time,
        rules: rules || [],
        state
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
      .select('created_by')
      .eq('id', id)
      .single();

    if (eventError) {
      return next(createError(404, 'Evento non trovato'));
    }

    if (event.created_by !== userId) {
      return next(createError(403, 'Solo il creatore può eliminare l\'evento'));
    }

    // Aggiorna lo stato invece di eliminare fisicamente
    const { error } = await supabaseClient
      .from('events')
      .update({ state: 'cancelled' })
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