// Middleware per la gestione degli errori
const errorHandler = (err, req, res, next) => {
  // Log dell'errore per debug
  console.error(err);

  // Imposta lo status code (default 500 se non specificato)
  const statusCode = err.statusCode || 500;
  
  // Formatta la risposta di errore
  const errorResponse = {
    success: false,
    error: {
      message: err.message || 'Si è verificato un errore interno del server',
      ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
    }
  };

  // Se ci sono errori di validazione, aggiungili alla risposta
  if (err.errors) {
    errorResponse.error.details = err.errors;
  }

  // Invia la risposta
  res.status(statusCode).json(errorResponse);
};

module.exports = errorHandler; 