importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js");

firebase.initializeApp({
    apiKey: "AIzaSyBRG0Ix2j3OgCgJPfQ986qGEVzg-ZeVfs8",
    authDomain: "fester-2921b.firebaseapp.com",
    projectId: "fester-2921b",
    storageBucket: "fester-2921b.firebasestorage.app",
    messagingSenderId: "969912900766",
    appId: "1:969912900766:web:cb8153206cde135e502f8f",
    measurementId: "G-QWKPHHJTGE"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
    console.log('[firebase-messaging-sw.js] Received background message ', payload);
    // Customize notification here
    const notificationTitle = payload.notification.title;
    const notificationOptions = {
        body: payload.notification.body,
        icon: '/icons/Icon-192.png'
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
});
