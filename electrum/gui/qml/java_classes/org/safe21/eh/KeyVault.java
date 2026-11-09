package org.safe21.eh;

import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;

import java.nio.charset.StandardCharsets;
import java.security.KeyStore;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/**
 * Easy Heirs (Schèi): the phone's safe.
 *
 * The wallet password is a long random secret. It is stored only "wrapped":
 * encrypted with an AES key that lives in the AndroidKeyStore (the secure chip
 * of the phone when there is one). The key never leaves the keystore and can be
 * used only by this app; it does NOT ask for a fingerprint (unlike Electrum's
 * BiometricActivity), so small payments go without questions. The PIN is a
 * separate check in the app (big payments, 12 words, advanced settings).
 * A copy of the files taken off the phone is useless without this key.
 */
public class KeyVault {
    private static final String ALIAS = "eh_wallet_vault_v1";
    private static final String KEYSTORE = "AndroidKeyStore";
    private static final String TRANSFORMATION = "AES/GCM/NoPadding";

    private static SecretKey getOrCreateKey() throws Exception {
        KeyStore ks = KeyStore.getInstance(KEYSTORE);
        ks.load(null);
        if (!ks.containsAlias(ALIAS)) {
            KeyGenerator kg = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE);
            kg.init(new KeyGenParameterSpec.Builder(ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .build());
            kg.generateKey();
        }
        return ((KeyStore.SecretKeyEntry) ks.getEntry(ALIAS, null)).getSecretKey();
    }

    /** Encrypt text with the keystore key. Result: base64(iv) + ":" + base64(ciphertext). */
    public static String wrap(String plain) throws Exception {
        Cipher c = Cipher.getInstance(TRANSFORMATION);
        c.init(Cipher.ENCRYPT_MODE, getOrCreateKey());
        byte[] ct = c.doFinal(plain.getBytes(StandardCharsets.UTF_8));
        return Base64.encodeToString(c.getIV(), Base64.NO_WRAP) + ":" + Base64.encodeToString(ct, Base64.NO_WRAP);
    }

    /** Decrypt what wrap() made. */
    public static String unwrap(String data) throws Exception {
        String[] parts = data.split(":", 2);
        byte[] iv = Base64.decode(parts[0], Base64.NO_WRAP);
        byte[] ct = Base64.decode(parts[1], Base64.NO_WRAP);
        Cipher c = Cipher.getInstance(TRANSFORMATION);
        c.init(Cipher.DECRYPT_MODE, getOrCreateKey(), new GCMParameterSpec(128, iv));
        return new String(c.doFinal(ct), StandardCharsets.UTF_8);
    }
}
