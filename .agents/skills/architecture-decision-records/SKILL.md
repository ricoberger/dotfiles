---
name: architecture-decision-records
description:
  Write and maintain Architecture Decision Records (ADRs) following best
  practices for technical decision documentation. Use when documenting
  significant technical decisions, reviewing past architectural choices, or
  establishing decision processes.
metadata:
  source: https://github.com/wshobson/agents/blob/main/plugins/documentation-generation/skills/architecture-decision-records/SKILL.md
---

# Architecture Decision Records

Comprehensive patterns for creating, maintaining, and managing Architecture
Decision Records (ADRs) that capture the context and rationale behind
significant technical decisions.

## When to Use This Skill

- Making significant architectural decisions
- Documenting technology choices
- Recording design trade-offs
- Onboarding new team members
- Reviewing historical decisions
- Establishing decision-making processes

## Core Concepts

### 1. What is an ADR?

An Architecture Decision Record captures:

- **Context**: Why we needed to make a decision
- **Decision**: What we decided
- **Consequences**: What happens as a result

### 2. When to Write an ADR

| Write ADR                  | Skip ADR               |
| -------------------------- | ---------------------- |
| New framework adoption     | Minor version upgrades |
| Database technology choice | Bug fixes              |
| API design patterns        | Implementation details |
| Security architecture      | Routine maintenance    |
| Integration patterns       | Configuration changes  |

### 3. ADR Lifecycle

```
Proposed → Accepted → Deprecated → Superseded
              ↓
           Rejected
```

- **Proposed**: Under discussion
- **Accepted**: Decision made, implementing
- **Deprecated**: No longer relevant
- **Superseded**: Replaced by another ADR
- **Rejected**: Considered but not adopted

## Template

```markdown
# ADR-0001: Use PostgreSQL as Primary Database

- Status:
- Date:
- Deciders:
- Consulted:
- Informed:

## Decision Outcome

One paragraph summary of the decision and its rationale.

## Context and Problem Statement

We need to select a primary database for our new e-commerce platform. The system
will handle:

- ~10,000 concurrent users
- Complex product catalog with hierarchical categories
- Transaction processing for orders and payments
- Full-text search for products
- Geospatial queries for store locator

The team has experience with MySQL, PostgreSQL, and MongoDB. We need ACID
compliance for financial transactions.

## Decision Drivers

- **Must have ACID compliance** for payment processing
- **Must support complex queries** for reporting
- **Should support full-text search** to reduce infrastructure complexity
- **Should have good JSON support** for flexible product attributes
- **Team familiarity** reduces onboarding time

## Considered Options

### Option 1: PostgreSQL

- **Pros**: ACID compliant, excellent JSON support (JSONB), built-in full-text
  search, PostGIS for geospatial, team has experience
- **Cons**: Slightly more complex replication setup than MySQL

### Option 2: MySQL

- **Pros**: Very familiar to team, simple replication, large community
- **Cons**: Weaker JSON support, no built-in full-text search (need
  Elasticsearch), no geospatial without extensions

### Option 3: MongoDB

- **Pros**: Flexible schema, native JSON, horizontal scaling
- **Cons**: No ACID for multi-document transactions (at decision time), team has
  limited experience, requires schema design discipline

## Decision

We will use **PostgreSQL 15** as our primary database.

## Rationale

PostgreSQL provides the best balance of:

1. **ACID compliance** essential for e-commerce transactions
2. **Built-in capabilities** (full-text search, JSONB, PostGIS) reduce
   infrastructure complexity
3. **Team familiarity** with SQL databases reduces learning curve
4. **Mature ecosystem** with excellent tooling and community support

The slight complexity in replication is outweighed by the reduction in
additional services (no separate Elasticsearch needed).

## Consequences

### Positive

- Single database handles transactions, search, and geospatial queries
- Reduced operational complexity (fewer services to manage)
- Strong consistency guarantees for financial data
- Team can leverage existing SQL expertise

### Negative

- Need to learn PostgreSQL-specific features (JSONB, full-text search syntax)
- Vertical scaling limits may require read replicas sooner
- Some team members need PostgreSQL-specific training

### Risks

- Full-text search may not scale as well as dedicated search engines
- Mitigation: Design for potential Elasticsearch addition if needed

## Implementation Notes

- Use JSONB for flexible product attributes
- Implement connection pooling with PgBouncer
- Set up streaming replication for read replicas
- Use pg_trgm extension for fuzzy search

## Related Decisions

- ADR-0002: Caching Strategy (Redis) - complements database choice
- ADR-0005: Search Architecture - may supersede if Elasticsearch needed

## References

- [PostgreSQL JSON Documentation](https://www.postgresql.org/docs/current/datatype-json.html)
- [PostgreSQL Full Text Search](https://www.postgresql.org/docs/current/textsearch.html)
- Internal: Performance benchmarks in `/docs/benchmarks/database-comparison.md`
```

## Review Process

```markdown
## ADR Review Checklist

### Before Submission

- [ ] Context clearly explains the problem
- [ ] All viable options considered
- [ ] Pros/cons balanced and honest
- [ ] Consequences (positive and negative) documented
- [ ] Related ADRs linked

### During Review

- [ ] At least 2 senior engineers reviewed
- [ ] Affected teams consulted
- [ ] Security implications considered
- [ ] Cost implications documented
- [ ] Reversibility assessed

### After Acceptance

- [ ] ADR index updated
- [ ] Team notified
- [ ] Implementation tickets created
- [ ] Related documentation updated
```

## Best Practices

### Do's

- **Write ADRs early** - Before implementation starts
- **Keep them short** - 1-2 pages maximum
- **Be honest about trade-offs** - Include real cons
- **Link related decisions** - Build decision graph
- **Update status** - Deprecate when superseded

### Don'ts

- **Don't change accepted ADRs** - Write new ones to supersede
- **Don't skip context** - Future readers need background
- **Don't hide failures** - Rejected decisions are valuable
- **Don't be vague** - Specific decisions, specific consequences
- **Don't forget implementation** - ADR without action is waste
