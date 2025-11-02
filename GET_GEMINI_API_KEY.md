# How to Get Gemini API Key

## Steps to get a free Gemini API key:

1. **Go to Google AI Studio**
   - Visit: https://makersuite.google.com/app/apikey
   - Or: https://aistudio.google.com/app/apikey

2. **Sign in with Google Account**
   - Use your Google account to sign in

3. **Create API Key**
   - Click "Create API Key"
   - Select a project or create a new one
   - Copy the generated API key

4. **Update the Code**
   - Open: `lib/services/presidio_service.dart`
   - Find line: `const geminiApiKey = 'AIzaSyBqJGVJKvYxGxGxGxGxGxGxGxGxGxGxGxG';`
   - Replace with your actual API key: `const geminiApiKey = 'YOUR_ACTUAL_API_KEY';`

## Free Tier Limits:
- 15 requests per minute
- 1 million tokens per minute
- 1,500 requests per day

## Example API Key Format:
```
AIzaSyBqJGVJKvYxGxGxGxGxGxGxGxGxGxGxGxG
```

## Security Note:
- Keep your API key secure
- Don't commit it to version control
- Consider using environment variables in production

## Test the Integration:
1. Add your API key to the code
2. Hot reload the Flutter app (`r`)
3. Go to Presidio Test screen
4. Enter text with PII
5. Process and check logs for real LLM responses