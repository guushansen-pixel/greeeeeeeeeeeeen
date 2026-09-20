package com.daniel.vokabeltrainer;

import android.app.Activity;
import android.speech.tts.TextToSpeech;
import android.webkit.JavascriptInterface;

import java.util.Locale;

/**
 * Sprachausgabe fuer die Web-App.
 *
 * Warum ueberhaupt nativ: die Web Speech API (window.speechSynthesis) ist in
 * einer Android-WebView nicht implementiert - in Chrome fuer Android laeuft
 * sie, in der WebView nicht (Chromium-Issue 487255, seit 2015 offen). Die
 * Web-App faellt deshalb nur im Desktop-Browser auf speechSynthesis zurueck
 * und benutzt auf dem Geraet diese Bruecke.
 *
 * Wichtig dazu im Manifest: ab targetSdk 30 sieht eine App fremde Dienste nur
 * noch, wenn sie sie in <queries> nennt. Ohne den Eintrag fuer
 * android.intent.action.TTS_SERVICE findet TextToSpeech keine Engine und
 * meldet still einen Init-Fehler (siehe build.ps1, Patch 3).
 *
 * Die Bruecke ist unbedenklich, weil die WebView ausschliesslich das eigene
 * gebuendelte Asset laedt (siehe LocalWebViewClient) - es gibt keine
 * Fremdseite, die addJavascriptInterface missbrauchen koennte.
 */
public class TtsBridge {

    /** Etwas langsamer als normal - es geht ums Nachsprechen, nicht ums Tempo. */
    private static final float RATE = 0.9f;

    private final Activity activity;
    private TextToSpeech tts;

    /** Wird vom Init-Callback auf einem anderen Thread gesetzt. */
    private volatile boolean ready = false;

    public TtsBridge(Activity activity) {
        this.activity = activity;
        this.tts = new TextToSpeech(activity, new TextToSpeech.OnInitListener() {
            @Override
            public void onInit(int status) {
                if (status != TextToSpeech.SUCCESS || tts == null) {
                    ready = false;
                    return;
                }
                // Green Line spielt in London, der Wortschatz ist britisches
                // Englisch - notfalls tut es auch eine US-Stimme.
                int r = tts.setLanguage(Locale.UK);
                if (r == TextToSpeech.LANG_MISSING_DATA || r == TextToSpeech.LANG_NOT_SUPPORTED) {
                    r = tts.setLanguage(Locale.US);
                }
                if (r == TextToSpeech.LANG_MISSING_DATA || r == TextToSpeech.LANG_NOT_SUPPORTED) {
                    ready = false;
                    return;
                }
                tts.setSpeechRate(RATE);
                ready = true;
            }
        });
    }

    /**
     * Die Initialisierung laeuft asynchron und dauert einen Moment. Die
     * Web-App fragt deshalb erst beim Sprechen, nicht beim Aufbau der Seite.
     */
    @JavascriptInterface
    public boolean isReady() {
        return ready;
    }

    @JavascriptInterface
    public void speak(final String text) {
        if (!ready || text == null || text.trim().length() == 0) {
            return;
        }
        // Methoden eines JavascriptInterface laufen auf einem
        // WebView-Hintergrundthread.
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (tts == null) {
                    return;
                }
                // QUEUE_FLUSH: schnelles Weiterklicken soll nicht zu einer
                // Warteschlange nachhallender Woerter fuehren.
                tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, "vokabel");
            }
        });
    }

    @JavascriptInterface
    public void stop() {
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (tts != null) {
                    tts.stop();
                }
            }
        });
    }

    /** Aus MainActivity.onDestroy() - nicht aus JavaScript erreichbar. */
    public void shutdown() {
        ready = false;
        if (tts != null) {
            tts.stop();
            tts.shutdown();
            tts = null;
        }
    }
}
