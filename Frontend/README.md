# TOEIC Reading portal

Flutter web and mobile client for teacher and student TOEIC Reading workflows.

## Routes

- Teacher portal: `/teacher`
- Student entry form: `/student`
- The student entry form asks for a name and student ID before showing tests available from the SQL database.

## Run the portals

For full copy-paste instructions covering SQL Server setup,
the ASP.NET API, teacher/student web URLs, mobile/emulator access,
tests, and troubleshooting, see [RUN_GUIDE.md](RUN_GUIDE.md).

Quick SQL-backed start (start SQL Server and the API as described in
[RUN_GUIDE.md](RUN_GUIDE.md), then launch Flutter):

```powershell
cd Frontend
flutter pub get
flutter run -d chrome --web-port 4200 --dart-define=API_BASE_URL=https://localhost:44311/
```

Open one of these exact portal URLs:

- Teacher: `http://localhost:4200/#/teacher`
- Student: `http://localhost:4200/#/student`

The student entry page does not show a link to the teacher portal.

The app defaults to the local API at `https://localhost:44311/`. Exam cards,
questions, and availability are loaded from the database; the app has no
bundled sample exams or questions.

API failures are surfaced; there is no local sample-data fallback.

The client uses the ABP exam list, preview, availability, exam update/delete,
and question-update endpoints. The backend stores exams in `Exams` and
questions in `ToeicQuestions`, matching the existing `ToeicExamDB` schema.
Teachers see all exams and can edit questions, set start/end times, enable or
disable availability, or permanently delete an exam. Availability is derived
from the start/end columns; automatic deletion and original-DOCX downloads are
not supported by this schema. Students only load exams currently within their
scheduled availability window.

DOCX uploads use `POST /api/exams/import`; imported documents must follow the
backend parser's expected tags, contain questions 101–200, and have four answer
options plus a correct-answer tag per question. A successful import immediately
creates an unavailable exam with no schedule and stores the parsed questions in
SQL. The uploaded source DOCX is parsed but not retained. Manual deletion
removes the exam and its dependent question rows immediately.

For the required Word document structure and a paste-ready template, see
[DOCX_IMPORT_GUIDE.md](DOCX_IMPORT_GUIDE.md).
