# Gestion-Solde

## Obtenir l'APK

Vous pouvez obtenir l'APK de deux façons : via le workflow GitHub Actions (recommandé) ou en construisant localement.

- Via GitHub Actions : poussez sur la branche `main` ou lancez manuellement le workflow `Build APK` (Actions → Build APK → Run workflow). Après exécution, allez dans la run correspondante et téléchargez l'artifact `app-release.apk` (section Artifacts).

	Avec l'outil GitHub CLI `gh` :

	```bash
	# Lancer le workflow
	gh workflow run build_apk.yml --ref main

	# Lister les runs pour récupérer l'ID
	gh run list --workflow build_apk.yml

	# Télécharger l'artifact (remplacez <run-id> par l'ID obtenu)
	gh run download <run-id> --name app-release.apk
	```

- Construction locale (nécessite Flutter installé) :

	```bash
	flutter pub get
	flutter create --platforms=android .
	flutter build apk --release --target=lib/main.dart

	# L'APK se trouvera ici : build/app/outputs/flutter-apk/app-release.apk
	```

Si vous n'avez pas Flutter localement, utilisez le workflow GitHub Actions pour générer l'APK et téléchargez l'artifact.
