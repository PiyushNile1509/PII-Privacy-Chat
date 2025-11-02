# Presidio Integration with Flutter App

This document explains how to integrate Microsoft Presidio with your Flutter application for advanced PII (Personally Identifiable Information) detection and anonymization.

## Overview

The integration provides:
- **Real-time PII Detection**: Uses Presidio Analyzer to identify sensitive information
- **Advanced Anonymization**: Uses Presidio Anonymizer to mask/replace PII
- **Privacy Scoring**: Calculates privacy scores based on detected entities
- **Fallback Support**: Falls back to existing backend if Presidio is unavailable
- **Test Interface**: Dedicated test screen to verify Presidio functionality

## Architecture

```
Flutter App
    ├── PresidioService (New)
    │   ├── Analyzer Integration
    │   └── Anonymizer Integration
    ├── PIIService (Updated)
    │   ├── Presidio Processing (Primary)
    │   └── Backend Processing (Fallback)
    └── Test Screens
        ├── PII Test (Existing)
        └── Presidio Test (New)
```

## Prerequisites

1. **Docker Desktop** - Required to run Presidio services
2. **Flutter SDK** - For the mobile app
3. **Network Access** - Presidio services run on localhost:3000 and localhost:3001

## Setup Instructions

### 1. Start Presidio Services

#### Option A: Using the Batch Script (Windows)
```bash
# Navigate to the project root
cd d:\Presido_Model

# Run the startup script
start-presidio.bat
```

#### Option B: Using Docker Compose Manually
```bash
# Navigate to the project root
cd d:\Presido_Model

# Start Presidio services
docker-compose -f docker-compose-presidio.yml up -d

# Check service health
curl http://localhost:3000/health  # Analyzer
curl http://localhost:3001/health  # Anonymizer
```

### 2. Verify Services

The services should be running on:
- **Presidio Analyzer**: http://localhost:3000
- **Presidio Anonymizer**: http://localhost:3001

### 3. Run Flutter App

```bash
cd d:\Presido_Model\presdio_pii
flutter run
```

## Using the Integration

### 1. Test Presidio Integration

1. Open the Flutter app
2. Tap the menu button (⋮) in the top-right corner
3. Select "Presidio Test"
4. Enter text with PII (e.g., "Hi, my name is John Doe. My email is john@example.com")
5. Tap "Process with Presidio"
6. Review the results:
   - Privacy Score
   - Detected Entities
   - Anonymized Text

### 2. Chat with PII Protection

1. From the main screen, start a new chat
2. Enter messages containing PII
3. The app will automatically:
   - Detect PII using Presidio
   - Anonymize sensitive information
   - Generate responses based on anonymized text
   - Calculate privacy scores

### 3. Fallback Behavior

If Presidio services are unavailable, the app will:
1. Attempt Presidio processing first
2. Fall back to the existing backend processing
3. Display appropriate error messages if both fail

## Supported PII Types

Presidio can detect and anonymize:

- **Personal Information**
  - Names (PERSON)
  - Email addresses (EMAIL_ADDRESS)
  - Phone numbers (PHONE_NUMBER)
  
- **Financial Information**
  - Credit card numbers (CREDIT_CARD)
  - US Social Security Numbers (US_SSN)
  - Bank account numbers
  
- **Identification**
  - Driver's license numbers (US_DRIVER_LICENSE)
  - Passport numbers
  - National ID numbers
  
- **Location & Time**
  - Addresses (LOCATION)
  - Dates and times (DATE_TIME)
  
- **And many more...**

## Configuration

### Presidio Service URLs

The app tries multiple URLs for each service:

**Analyzer URLs:**
- http://localhost:3000 (Primary)
- http://127.0.0.1:3000
- http://10.0.2.2:3000 (Android Emulator)

**Anonymizer URLs:**
- http://localhost:3001 (Primary)
- http://127.0.0.1:3001
- http://10.0.2.2:3001 (Android Emulator)

### Anonymization Rules

Default anonymization configuration:
```dart
{
  'PERSON': {'type': 'replace', 'new_value': '[PERSON]'},
  'EMAIL_ADDRESS': {'type': 'replace', 'new_value': '[EMAIL]'},
  'PHONE_NUMBER': {'type': 'replace', 'new_value': '[PHONE]'},
  'CREDIT_CARD': {'type': 'replace', 'new_value': '[CREDIT_CARD]'},
  'US_SSN': {'type': 'replace', 'new_value': '[SSN]'},
  // ... more rules
}
```

### Privacy Score Calculation

Privacy scores are calculated based on:
- **Entity Type Impact**: Different PII types have different impact scores
- **Confidence Level**: Higher confidence detections have more impact
- **Text Coverage**: Larger PII entities relative to text size have more impact

Impact scores:
- SSN, Credit Card: 25 points
- Email, Phone: 15 points
- Names: 10 points
- Dates, Locations: 5 points

## Troubleshooting

### Common Issues

1. **Services Not Starting**
   ```bash
   # Check Docker is running
   docker --version
   
   # Check service logs
   docker-compose -f docker-compose-presidio.yml logs
   ```

2. **Connection Refused**
   - Ensure Docker Desktop is running
   - Check if ports 3000 and 3001 are available
   - Verify firewall settings

3. **Flutter App Not Connecting**
   - Check service health in Presidio Test screen
   - Verify network connectivity
   - Check console logs for error messages

### Service Management

```bash
# Stop services
docker-compose -f docker-compose-presidio.yml down

# Restart services
docker-compose -f docker-compose-presidio.yml restart

# View logs
docker-compose -f docker-compose-presidio.yml logs -f

# Check service status
docker-compose -f docker-compose-presidio.yml ps
```

## Development Notes

### Key Files Added/Modified

**New Files:**
- `lib/services/presidio_service.dart` - Main Presidio integration
- `lib/presidio_test_screen.dart` - Test interface for Presidio
- `docker-compose-presidio.yml` - Docker services configuration
- `start-presidio.bat` - Windows startup script

**Modified Files:**
- `lib/services/pii_service.dart` - Updated to use Presidio first
- `lib/main_screen.dart` - Added menu access to test screens

### API Endpoints

**Presidio Analyzer:**
- `GET /health` - Health check
- `POST /analyze` - Analyze text for PII
- `GET /supportedentities` - Get supported entity types

**Presidio Anonymizer:**
- `GET /health` - Health check
- `POST /anonymize` - Anonymize text
- `GET /anonymizers` - Get available anonymizers

### Error Handling

The integration includes comprehensive error handling:
- Service availability checks
- Timeout handling (10 seconds for processing, 5 seconds for health checks)
- Graceful fallback to existing backend
- User-friendly error messages

## Performance Considerations

- **Cold Start**: First request may take longer as services initialize
- **Processing Time**: Typically 1-3 seconds for text analysis and anonymization
- **Memory Usage**: Presidio services require ~500MB RAM each
- **Network**: All communication is local (localhost)

## Security Notes

- Presidio services run locally, no data leaves your machine
- Original text is processed in memory only
- Anonymized results can be safely logged or transmitted
- Privacy scores help assess data sensitivity

## Future Enhancements

Potential improvements:
1. **Custom Recognizers**: Add domain-specific PII detection
2. **Deanonymization**: Implement reversible anonymization for authorized users
3. **Batch Processing**: Process multiple messages simultaneously
4. **Configuration UI**: Allow users to customize anonymization rules
5. **Performance Monitoring**: Add metrics and performance tracking

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Docker and Presidio logs
3. Test with the Presidio Test screen
4. Verify service health endpoints

## References

- [Microsoft Presidio Documentation](https://microsoft.github.io/presidio/)
- [Presidio Analyzer API](https://microsoft.github.io/presidio/analyzer/)
- [Presidio Anonymizer API](https://microsoft.github.io/presidio/anonymizer/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)