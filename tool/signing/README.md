# Firma dell'app

Per ora gli APK escono con la firma di debug di GitHub: va bene per provarli,
ma ogni nuova versione va installata dopo aver disinstallato la precedente.

Quando si vorrà una firma fissa, il workflow usa `tool/signing/app.jks`
(alias `app`) con la password nel segreto GitHub `KS_PASS`.
