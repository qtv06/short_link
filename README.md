# Short Link Service

A high-performance URL shortening service built with Ruby on Rails, featuring a counter-based approach with caching for optimal performance and security.

## Introduction

This project implements a URL shortening service similar to bit.ly or tinyurl.com. The service takes long URLs and converts them into short, shareable links while maintaining high performance and preventing common security issues.

### Key Features

- **Counter-based short code generation** for guaranteed uniqueness and avoid collisions
- **Rate limiting** to prevent abuse (20 requests per 5 minutes)
- **Redis caching** for high-performance lookups
- **Base62 encoding** with randomized character set for security
- **PostgreSQL** for persistent storage
- **RESTful API** with JSON responses
- **Docker containerization** for easy deployment

## Setup via Docker

### Prerequisites

- Docker and Docker Compose installed on your system

### Environment Configuration

Create a `.env` file in the project root with the following variables:

```env
SHORT_LINK_DATABASE_HOST=db
SHORT_LINK_DATABASE_PORT=5432
SHORT_LINK_DATABASE_USERNAME=postgres
SHORT_LINK_DATABASE_PASSWORD=password
SHORT_LINK_REDIS_URL=redis://redis:6379
SHORT_LINK_HOST=localhost:3000
```

### Running the Application

1. Clone the repository:
```bash
git clone <repository-url>
cd short_link
```

2. Create the `.env` file as described above

3. Build and start the services:
```bash
docker-compose up --build
```

4. In a separate terminal, set up the database:
```bash
docker-compose exec app rails db:create db:migrate db:seed
```

5. Initialize the URL counter in Redis:
```bash
docker-compose exec app rails runner "Link.initialize_url_counter"
```

The application will be available at `http://localhost:3000`

## Architecture

### Overview

The service uses a **counter-based approach** with caching for generating short URLs. This architecture provides several advantages over hash-based solutions.

### Encoding Flow (Create Short Link)

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│POST /encode │───▶│Rate Limiting│───▶│  Rails App  │───▶│Redis Counter│───▶│Base62 Encode│
└─────────────┘    │20 req/5min  │    └─────────────┘    │(starts: 1B) │    │(Random Set) │
                   └─────────────┘                       └─────────────┘    └─────────────┘
                          │                                                        │
                          ▼                                                        ▼
                   ┌─────────────┐                                          ┌─────────────┐
                   │ 429 Error   │                                          │ PostgreSQL  │
                   └─────────────┘                                          │Store Mapping│
                                                                            └─────────────┘
                                                                                   │
                                                                                   ▼
┌─────────────┐                                                             ┌─────────────┐
│Return JSON  │◀────────────-------─────────────────────────────────────────│ Redis Cache │
│201 Created  │                                                             │             │
└─────────────┘                                                             └─────────────┘
```

### Decoding Flow (Resolve Short Link)

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│GET /short_  │───▶│  Rails App  │───▶│Redis Cache  │
│    code     │    │             │    │Check First  │
└─────────────┘    └─────────────┘    └─────────────┘
                                             │
                                    ┌────────┴────────┐
                                    ▼                 ▼
                            ┌─────────────┐   ┌─────────────┐
                            │ Cache HIT   │   │ Cache MISS  │
                            │(Fast Path)  │   │             │
                            └─────────────┘   └─────────────┘
                                    │                 │
                                    │                 ▼
                                    │         ┌─────────────┐    ┌─────────────┐
                                    │         │ PostgreSQL  │───▶│Update Cache │
                                    │         │  Database   │    │(12h TTL)    │
                                    │         │  Query      │    └─────────────┘
                                    │         └─────────────┘            │
                                    │                 │                  │
                                    └─────────────────┴──────────────────┘
                                                      │
                                                      ▼
                                             ┌─────────────┐
                                             │301 Redirect │
                                             │to Original  │
                                             │    URL      │
                                             └─────────────┘
```

### Counter + Cache Strategy

#### How it Works

1. **Counter Generation**: Each new URL gets a unique sequential counter starting from 1,000,000,000
2. **Base62 Encoding**: The counter is encoded using a randomized Base62 character set
3. **Database Storage**: The mapping is stored in PostgreSQL for persistence
4. **Redis Caching**: Frequently accessed mappings are cached for 12 hours

#### Security Mitigations

1. **Randomized Character Set**: The Base62 encoding uses a shuffled character set instead of the standard 0-9A-Za-z order
   ```ruby
   CHARS = "RO9zDGxetiA5flHnXvU8M1WmJNqwhK6TaSVQjgPkIsFbc04pL7yoCurBdEZ32Y"
   ```
   This prevents attackers from easily guessing sequential URLs.

2. **High Starting Counter**: Starting from 1 billion makes the URLs less predictable and more professional-looking.

3. **Cache Invalidation**: Cached entries expire after 12 hours to prevent indefinite exposure.

#### Collision Prevention

- **Atomic Counter Increment**: Redis atomic increment ensures no two requests get the same counter value
- **Database Unique Constraint**: The `short_code` field has a unique index preventing duplicates
- **Retry Logic**: If a collision occurs (extremely rare), the system retries with a new counter value

#### Performance Optimizations

1. **Redis Caching**:
   - 12-hour expiration balances memory usage and performance
   - Sub-millisecond lookup times

2. **Atomic Operations**:
   - Redis increment operations are atomic and fast
   - No database queries needed for counter generation

3. **Rate Limiting**: The application implements rate limiting to prevent abuse of the encoding endpoint.

### Comparison with Hash-based Solutions

| Aspect | Counter-based (This Project) | Hash-based (MD5/SHA) |
|--------|------------------------------|---------------------|
| **Uniqueness** | ✅ Guaranteed by atomic counter | ❌ Collision possible, needs handling |
| **Performance** | ✅ O(1) generation, cached lookups | ❌ Hash computation overhead |
| **URL Length** | ✅ Short, predictable length (6 chars) | ❌ Fixed length, often longer |
| **Security** | ❌ Predictable patterns | ✅ Unpredictable patterns |
| **Scalability** | ✅ Horizontal scaling with Redis | ❌ CPU-intensive hashing |
| **Storage** | ✅ Minimal database queries | ❌ Collision resolution complexity |

## API Documentation

### Base URL
```
http://localhost:3000
```

### Endpoints

#### 1. Encode URL (Create Short Link)

**POST** `/encode`

Creates a short link for the provided URL.

**Request:**
```json
{
  "original_url": "https://www.example.com/very/long/url/path"
}
```

**Response:**
```json
{
  "data": {
    "id": 1,
    "original_url": "https://www.example.com/very/long/url/path",
    "short_code": "RO9zDG",
    "shortened_url": "http://localhost:3000/RO9zDG",
    "created_at": "2025-08-03T10:30:00.000Z"
  }
}
```

**Status Codes:**
- `201 Created` - Successfully created
- `422 Unprocessable Entity` - Invalid URL format

---

#### 2. Decode Short Link

**GET** `/decode?short_code={short_code}`

Retrieves the original URL information for a short code.

**Request:**
```
GET /decode?short_code=RO9zDG
```

**Response:**
```json
{
  "data": {
    "id": 1,
    "original_url": "https://www.example.com/very/long/url/path",
    "short_code": "RO9zDG",
    "shortened_url": "http://localhost:3000/RO9zDG",
    "created_at": "2025-08-03T10:30:00.000Z"
  }
}
```

**Status Codes:**
- `200 OK` - Successfully retrieved
- `404 Not Found` - Short code not found

---

#### 3. Redirect to Original URL

**GET** `/{short_code}`

Redirects to the original URL associated with the short code.

**Request:**
```
GET /RO9zDG
```

**Response:**
- **Status Code:** `301 Moved Permanently`
- **Location Header:** `https://www.example.com/very/long/url/path`

**Status Codes:**
- `301 Moved Permanently` - Successfully redirected
- `404 Not Found` - Short code not found

### Example Usage

```bash
# Create a short link
curl -X POST http://localhost:3000/encode \
  -H "Content-Type: application/json" \
  -d '{"original_url": "https://www.example.com"}'

# Get link information
curl http://localhost:3000/decode?short_code=RO9zDG

# Use the short link (redirects)
curl -L http://localhost:3000/RO9zDG
```

## Future Enhancements

### Security & Authentication
- [ ] **API Authentication** - JWT tokens or API keys for protected endpoints
- [ ] **User Management** - User accounts and link ownership
- [ ] **HTTPS Enforcement** - SSL/TLS configuration for production

### Monitoring & Observability
- [ ] **Application Metrics** - Prometheus/Grafana integration
- [ ] **Health Checks** - Comprehensive system health monitoring
- [ ] **Alert System** - Automated alerts for system issues

### Features & UX
- [ ] **Analytics Dashboard** - Click tracking and usage statistics
- [ ] **Custom Short Codes** - Allow users to specify custom short URLs
- [ ] **Bulk Operations** - Batch URL creation and management
- [ ] **Link Expiration** - Time-based link expiration
- [ ] **QR Code Generation** - Auto-generate QR codes for short links

## Development

### Running Tests

```bash
# Run all tests
docker-compose exec app bundle exec rspec

# Run specific test file
docker-compose exec app bundle exec rspec test/models/link_test.rb
```

### Database Operations

```bash
# Create and migrate database
docker-compose exec app rails db:create db:migrate

# Seed the database
docker-compose exec app rails db:seed

# Reset database
docker-compose exec app rails db:reset
```

### Monitoring

- **Application logs**: `docker-compose logs app`
- **Database logs**: `docker-compose logs db`
- **Redis logs**: `docker-compose logs redis`

*Built with ❤️ using Ruby on Rails, PostgreSQL, and Redis*