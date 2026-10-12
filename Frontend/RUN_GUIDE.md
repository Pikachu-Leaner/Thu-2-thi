# Run the TOEIC teacher and student portals

This project has two separate student/teacher entry links in the same Flutter
web app. Use these exact URLs:

- Teacher: `http://localhost:4200/#/teacher`
- Student: `http://localhost:4200/#/student`

Students should open the student link directly. The student page has no
navigation button to the teacher portal.

Run the SQL-backed setup for DOCX import and persistent exam management. All
exam cards and questions shown in the app come from SQL; the app does not
include sample exams or sample questions. The backend targets the existing
`ToeicExamDB` database and its `Exams` and `ToeicQuestions` tables.

## Requirements

- Flutter SDK (the project uses Dart 3.13.4 or later)
- .NET 9 SDK
- SQL Server Express, configured to use the instance `localhost\SQLEXPRESS`
- Chrome for the web version, or an Android/iOS emulator or connected phone

## Start the SQL-backed app (DOCX import enabled)

### 1. Start SQL Server

Start the `SQL Server (SQLEXPRESS)` Windows service and make sure the database
connection in the backend configuration points to the SQL Server instance you
are running. The default connection is in
`Backend/HoangThong.MyProject/10.2.0/aspnet-core/src/HoangThong.MyProject.Web.Host/appsettings.json`.

### 2. Check the existing database schema

The default backend connection targets `ToeicExamDB`, which should already
contain the `Exams` and `ToeicQuestions` tables. Do not run the migrator against
this pre-created database unless its EF migration history has been set up for
this backend: the migrator includes the application's full historical schema
and can conflict with existing tables. The new alignment migration is for
upgrading a legacy backend database that has already applied the earlier exam
migrations; back up and verify such a database before applying it.

The Web Host is configured with `App:UseExamOnlyDatabase` set to `true` for
this two-table database. This skips ABP seed data, database-backed
localization, background jobs, and audit logging, which require additional ABP
tables. If you instead use a fully migrated ABP database, set this option to
`false` in the Web Host's `appsettings.json`.

### 2. Start the ASP.NET API

In a **second PowerShell window**:

```powershell
cd Backend\HoangThong.MyProject\10.2.0\aspnet-core
dotnet dev-certs https --trust
dotnet run --project src\HoangThong.MyProject.Web.Host
```

Keep this window open. The configured API address is
`https://localhost:44311/`. If Windows asks whether to trust the development
certificate, allow it. The certificate command may also open a confirmation.

### 3. Start Flutter connected to the API

In a **third PowerShell window**:

```powershell
cd Frontend
flutter pub get
flutter run -d chrome --web-port 4200 --dart-define=API_BASE_URL=https://localhost:44311/
```

Open only the appropriate link above. Both portals use the same exact backend
API base URL, `https://localhost:44311/`; their portal routes select teacher
versus student functionality. The backend must be running at that URL before
either page can load database data. API errors are shown if it is unavailable;
the app never uses local sample data.

The teacher portal shows all exams, including exams without an availability
schedule. Import a DOCX to create an unavailable exam, edit its questions, then
set start and end times to make it available to students. The student portal
only shows exams whose current time falls within that window. The source DOCX
is parsed during import and is not retained; automatic exam deletion is not
supported by the two-table schema. All tests use a 75-minute time limit.

The app defaults to the local SQL-backed API at
`https://localhost:44311/`. Start SQL Server and the API before launching
Flutter. If the API is stopped, the app reports a connection error.

## Run on a phone or emulator

First start SQL Server and the API as described above. Then list available
Flutter targets:

```powershell
cd Frontend
flutter devices
```

For an Android emulator, the host computer is usually reachable at
`10.0.2.2`. Run (replace `<device-id>` with the ID from `flutter devices`):

```powershell
flutter run -d <device-id> --dart-define=API_BASE_URL=https://10.0.2.2:44311/
```

The Android emulator reaches the same API host through `10.0.2.2`; the exact
web API address remains `https://localhost:44311/`.

For a physical phone, replace `10.0.2.2` with the computer's LAN IP address,
make sure the phone and computer share a network, and allow the API port through
the Windows firewall. A development HTTPS certificate is not automatically
trusted by a phone; for device testing, configure a trusted HTTPS endpoint or
use the project's approved local-development certificate setup. Open the
student or teacher route on the device as appropriate.

## Common commands

Run Flutter checks:

```powershell
cd Frontend
flutter analyze
flutter test
```

Build the web release:

```powershell
cd Frontend
flutter build web --release --dart-define=API_BASE_URL=https://localhost:44311/
```

## Troubleshooting

- **SQL connection error:** Verify SQL Server Express is running and that the
  connection string in the Web Host configuration points to the server and
  `ToeicExamDB` database containing the expected exam tables.
- **API certificate warning or request failure:** Run
  `dotnet dev-certs https --trust`, restart the API, and reload the browser.
- **CORS error:** The default backend configuration allows
  `http://localhost:4200`. Use that exact origin when opening Flutter web.
- **No tests shown to students:** Tests must be enabled and the current time
  must be between each test's configured start and end times.
- **DOCX import validation error:** Check the file against
  [DOCX_IMPORT_GUIDE.md](DOCX_IMPORT_GUIDE.md); the importer requires 100
  questions numbered 101–200 and all required markup.
- **Mobile device cannot connect:** Use the host computer's LAN IP for a
  physical phone; `localhost` on the phone refers to the phone itself.
- **Gradle cannot download Android dependencies:** This is a network/dependency
  download issue; retry the Android build when the development machine can reach
  Google Maven and Maven Central.
