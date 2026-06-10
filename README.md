Auteur : Théo Brasseur | https://github.com/TheoBrasseurSSI | https://linkedin.com/in/tbrasseur



\---

Outil PowerShell de purge ciblée des emails de phishing sur un tenant Microsoft 365. Il permet à un administrateur de supprimer en masse, sur toutes les boîtes du tenant, les messages provenant d'un expéditeur précis à partir d'une date donnée — y compris les mails issus de comptes légitimes compromis, non détectés par les filtres antispam natifs.

\---

> ⚠ La suppression est définitive ! Aucun retour arrière possible !

> ⚠ Même après une purge HardDelete réussie, les mails peuvent encore apparaître temporairement dans les résultats si vous relancez l'outil. Cela est dû au délai de rafraîchissement de l'index Exchange. Les tests réalisés confirment toutefois que les messages sont bien supprimés immédiatement côté serveur.

\---

## Prérequis

* Compte Microsoft 365 avec au moins l'un des rôles suivants :

  * eDiscovery Manager
  * ou Compliance Administrator
* ⚠ Ne pas exécuter dans PowerShell ISE

\---

## Portée de la suppression

* Par défaut dans le script : `-ExchangeLocation All` → Suppression dans tout le tenant.
* Pour limiter à une ou plusieurs boîtes, modifier la ligne dans le script :

  * Une seule boîte : `-ExchangeLocation "user@domaine.fr"`
  * Plusieurs boîtes : `-ExchangeLocation "user1@domaine.fr","user2@domaine.fr"`
* Repasser sur `All` pour une purge globale.

\---

## Saisie utilisateur

Lors de l'exécution, le script demande :

* L'adresse email de l'expéditeur ciblé
* Une date de début au format `jj/mm/aaaa`

Tous les messages envoyés par cet expéditeur à partir de cette date seront supprimés.

\---

## Lancement

* Créez un raccourci de `Launcher.bat` → clic-droit → Créer un raccourci.
* Le fichier `.bat` :

  * applique une `ExecutionPolicy Bypass` (temporaire, pour la session uniquement)
  * exécute ensuite le script `PurgePhishing.ps1`
* ⚠ Le fichier `Launcher.bat` et le fichier `PurgePhishing.ps1` doivent rester dans le même dossier.
* Un fichier `.ico` est fourni pour l'icône de votre raccourci.

\---

## Exécution manuelle

Le script peut aussi être lancé directement depuis PowerShell :

```powershell
powershell.exe -ep Bypass -File .\\PurgePhishing.ps1
```

Le bypass est temporaire et n'applique aucune modification permanente sur le poste.

\---

## Logs

* Un fichier de log est automatiquement généré à chaque exécution.
* Le dossier `logs\\` est créé automatiquement au premier lancement, aucune action manuelle nécessaire.
* Les logs sont stockés dans le dossier `logs\\` à la racine du projet.
* Chaque fichier est nommé avec le timestamp de la session : `Purge\_2026-06-10\_15-01.log`
* Le log contient : compte admin utilisé, expéditeur ciblé, date de début, nombre d'emails trouvés, action effectuée (supprimé/annulé).
* ⚠ Le dossier `logs\\` est exclu du dépôt Git (`.gitignore`) — vos logs restent locaux.

