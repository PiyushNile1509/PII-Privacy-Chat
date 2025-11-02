@echo off
echo Testing Presidio Services...
echo.

echo Testing Presidio Analyzer...
curl -X POST http://localhost:3000/analyze ^
  -H "Content-Type: application/json" ^
  -d "{\"text\": \"My name is John Doe and my email is john.doe@example.com\", \"language\": \"en\"}"

echo.
echo.

echo Testing Presidio Anonymizer...
curl -X POST http://localhost:3001/anonymize ^
  -H "Content-Type: application/json" ^
  -d "{\"text\": \"My name is John Doe and my email is john.doe@example.com\", \"analyzer_results\": [{\"entity_type\": \"PERSON\", \"start\": 11, \"end\": 19, \"score\": 0.85}, {\"entity_type\": \"EMAIL_ADDRESS\", \"start\": 36, \"end\": 56, \"score\": 1.0}], \"anonymizers\": {\"PERSON\": {\"type\": \"replace\", \"new_value\": \"[PERSON]\"}, \"EMAIL_ADDRESS\": {\"type\": \"replace\", \"new_value\": \"[EMAIL]\"}}}"

echo.
echo.
echo Test completed.
pause