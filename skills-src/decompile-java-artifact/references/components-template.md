# <app name>: components (decompiled)

Source of this text: the decompiled code in this folder only. Written <date>.

## 1. What the artifact is

| Item | Value | Where it comes from |
|---|---|---|
| Packaging | Spring Boot fat JAR / WAR / plain JAR | layout of the archive |
| Entry point | start class, or `WebApplicationInitializer`, or `web.xml` servlet | `_meta/MANIFEST.MF`, INVENTORY |
| Framework versions | Spring Boot x, Spring Framework y, Hibernate z | MANIFEST, DEPENDENCIES.md |
| Java | compiled for N, built with JDK M | MANIFEST (`Java-Version`, `Build-Jdk-Spec`) |
| Version and commit | | `_meta/git.properties`, `build-info.properties` |
| App classes | count, packages | DECOMPILE-REPORT.txt |
| Libraries | count, how many exact | DEPENDENCIES.md |
| Server-provided libraries | for example Servlet API | embedded pom.xml (`provided`) |

## 2. Architecture in one view

Name the style (package-by-feature, layered, hexagonal, modular monolith). Draw one text diagram: entry → web → service → data, plus caches, messaging, outbound calls, schedulers. Name the seams (interfaces) and their adapters, if any.

## 3. Components

One sub-section for each group. Use a table: class, role, key behavior.
- 3.1 Bootstrap and configuration (including XML, profiles, data source, security)
- 3.2 Domain model (entities, tables, relations, fetch types, aggregate roots)
- 3.3 Services (transactions, caching, business rules)
- 3.4 Data access (repositories, queries, JDBC/JPA/Spring Data)
- 3.5 Web layer (endpoints from INVENTORY, validation, binding rules)
- 3.6 Integration (messaging listeners, scheduled jobs, outbound HTTP, files)
- 3.7 Cross-cutting (aspects, filters, interceptors, exception handling)
- 3.8 Views and static files (templates, JSP, i18n)

## 4. Risks and failure modes seen in the code

Only things that you saw in this code, each with the file. Examples of what to look for: EAGER fetch graphs, N+1 queries, missing transactions, unbounded queries, global locks, caches without eviction, exposed actuator, secrets in config (masked), unsafe query building, error text used as logic, container or version constraints. Add the confirmed HIGH items from RISKS.md.

## 5. What this decompile cannot show

- Comments, design intent, tests, CI, deployment files (Dockerfile, Helm, k8s).
- Runtime config outside the artifact: environment variables, JVM `-D` options, JNDI resources, Kubernetes ConfigMaps and Secrets, server config (Tomcat `context.xml`, `setenv.sh`).
- Server-provided libraries and their versions.
- The active Spring profile in production.

List the questions to ask the owning team or DevOps to fill these gaps.
