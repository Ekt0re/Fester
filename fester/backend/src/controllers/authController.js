const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const createError = require('http-errors');
const { supabaseAdmin } = require('../config/supabase');
require('dotenv').config();

// Registrazione nuovo utente
const register = async (req, res, next) => {
  try {
    const { email, password, nome, cognome } = req.body;

    // Registra l'utente tramite Supabase Auth
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { nome, cognome }
    });

    if (authError) {
      return next(createError(400, authError.message));
    }

    // Genera token JWT
    const token = jwt.sign(
      { id: authData.user.id, email: authData.user.email },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.status(201).json({
      success: true,
      data: {
        user: {
          id: authData.user.id,
          email: authData.user.email,
          nome,
          cognome
        },
        token
      }
    });
  } catch (error) {
    next(error);
  }
};

// Login utente
const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    // Autenticazione tramite Supabase
    const { data, error } = await supabaseAdmin.auth.signInWithPassword({
      email,
      password
    });

    if (error) {
      return next(createError(401, 'Credenziali non valide'));
    }

    // Genera token JWT
    const token = jwt.sign(
      { id: data.user.id, email: data.user.email },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.status(200).json({
      success: true,
      data: {
        user: {
          id: data.user.id,
          email: data.user.email,
          ...data.user.user_metadata
        },
        token
      }
    });
  } catch (error) {
    next(error);
  }
};

// Ottieni profilo utente
const getProfile = async (req, res, next) => {
  try {
    const userId = req.user.id;

    // Ottieni dati utente da Supabase
    const { data, error } = await supabaseAdmin.auth.admin.getUserById(userId);

    if (error) {
      return next(createError(404, 'Utente non trovato'));
    }

    res.status(200).json({
      success: true,
      data: {
        id: data.user.id,
        email: data.user.email,
        ...data.user.user_metadata
      }
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  register,
  login,
  getProfile
}; 