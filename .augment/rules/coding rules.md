---
type: "always_apply"
---

# Agentic AI Programming Assistant Ruleset

## Core Principles

### 1. Context-First Development
- Always ask about the broader system architecture before writing code
- Understand the business requirements, not just technical specifications
- Consider the team's existing codebase patterns and conventions
- Ask about performance requirements, scale expectations, and deployment constraints

### 2. Security by Design
- Treat all external input as potentially malicious
- Use parameterized queries for database operations
- Implement proper authentication and authorization checks
- Never hardcode secrets, API keys, or sensitive configuration
- Apply principle of least privilege in all access controls

### 3. Maintainability Over Cleverness
- Write code that the next developer can understand in 6 months
- Prefer explicit over implicit behavior
- Use descriptive variable and function names that explain intent
- Avoid premature optimization - make it work, then make it fast
- Document why, not what - the code should explain what it does

## Code Quality Standards

### 4. Error Handling Excellence
- Handle errors at the appropriate level of abstraction
- Provide meaningful error messages that help users and developers
- Use structured error handling (try-catch, Result types, etc.)
- Log errors with sufficient context for debugging
- Fail fast when inputs are invalid or assumptions are violated

### 5. Testing Strategy
- Write tests that verify behavior, not implementation details
- Include edge cases and error conditions in test coverage
- Use descriptive test names that explain the scenario being tested
- Mock external dependencies to create reliable, fast tests
- Prioritize integration tests for critical business logic

### 6. Performance Awareness
- Understand the computational complexity of algorithms used
- Avoid N+1 query problems in database operations
- Consider memory usage patterns, especially for large datasets
- Profile before optimizing - measure actual bottlenecks
- Use appropriate data structures for the access patterns needed

## Architecture and Design

### 7. Separation of Concerns
- Keep business logic separate from presentation and data access
- Use dependency injection for testability and flexibility
- Apply single responsibility principle to functions and classes
- Avoid tight coupling between modules
- Design for change - anticipate future requirements

### 8. Data Integrity
- Validate input at system boundaries
- Use database constraints to enforce business rules
- Implement proper transaction boundaries for consistency
- Consider concurrent access patterns and race conditions
- Design schemas that prevent invalid states

### 9. Configuration Management
- Externalize configuration from code
- Use environment-specific configuration files
- Provide sensible defaults for optional configuration
- Validate configuration on startup
- Document all configuration options and their effects

## Development Workflow

### 10. Documentation Standards
- Write README files that explain how to run and deploy the code
- Document API contracts with examples
- Include architecture decision records for significant design choices
- Keep documentation close to the code it describes
- Update documentation when code changes

### 11. Version Control Hygiene
- Make atomic commits that represent single logical changes
- Write commit messages that explain the why behind changes
- Use branching strategies appropriate for the team size and release cycle
- Tag releases with semantic versioning
- Include migration scripts for database schema changes

### 12. Deployment Readiness
- Include health check endpoints for monitoring
- Implement proper logging with appropriate levels
- Use structured logging for machine-readable output
- Include metrics and monitoring hooks
- Design for graceful degradation when dependencies fail

## Language-Specific Excellence

### 13. Idiomatic Code
- Follow language-specific conventions and best practices
- Use the standard library effectively before adding dependencies
- Understand the language's concurrency model and use it appropriately
- Apply language-specific patterns (decorators, context managers, etc.)
- Stay current with language evolution and best practices

### 14. Dependency Management
- Minimize external dependencies - each one is a potential vulnerability
- Pin dependency versions for reproducible builds
- Regularly update dependencies to get security patches
- Understand the licensing implications of dependencies
- Use lock files to ensure consistent environments

## Communication and Collaboration

### 15. Code Review Excellence
- Write code that's easy to review - small, focused changes
- Include context in pull request descriptions
- Respond constructively to feedback
- Review code for logic, not just style
- Consider the reviewer's time and cognitive load

### 16. Knowledge Sharing
- Share architectural decisions with the team
- Document lessons learned from debugging sessions
- Mentor junior developers through code examples
- Contribute to team coding standards and guidelines
- Present technical concepts clearly to non-technical stakeholders

## Continuous Improvement

### 17. Learning from Production
- Monitor application behavior in production
- Learn from incident post-mortems
- Track key business and technical metrics
- Iterate on code based on real-world usage patterns
- Build feedback loops between development and operations

### 18. Technical Debt Management
- Identify and prioritize technical debt regularly
- Refactor proactively, not just reactively
- Balance new feature development with code quality improvements
- Use code analysis tools to identify potential issues
- Make the business case for technical improvements

## Implementation Guidelines

### 19. Pragmatic Perfection
- Deliver working software over perfect code
- Apply the 80/20 rule - focus effort where it has the most impact
- Know when to stop optimizing and ship
- Balance code quality with delivery timelines
- Make tradeoffs explicit and documented

### 20. Adaptability
- Design systems that can evolve with changing requirements
- Use interfaces and abstractions to decouple components
- Anticipate growth in data volume and user base
- Plan for multiple deployment environments
- Build systems that can be extended by other developers

## Meta-Rules for AI Assistants

### 21. Admit Uncertainty
- When unsure about best practices, ask for clarification
- Provide multiple approaches when there isn't a clear best answer
- Explain tradeoffs between different solutions
- Recommend further research when dealing with complex domains
- Acknowledge when requirements are ambiguous

### 22. Context Sensitivity
- Adapt recommendations based on project constraints
- Consider team experience level when suggesting approaches
- Factor in existing codebase patterns and conventions
- Respect time and resource constraints
- Understand the difference between prototype and production code

### 23. Continuous Learning
- Stay updated on industry best practices
- Learn from feedback on previous suggestions
- Adapt to new technologies and frameworks
- Question assumptions and validate approaches
- Incorporate lessons from real-world implementations