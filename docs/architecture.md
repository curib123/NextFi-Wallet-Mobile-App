# Architecture

## Structure

The codebase is organized around three top-level areas inside `lib/`:

- `app/`: application shell, bootstrap, theme, app-wide providers, and shared app-level view models.
- `core/`: reusable cross-feature services, models, utilities, and UI building blocks.
- `features/`: feature-scoped code grouped by `data/` and `presentation/`.

## Folder rules

- Keep app-wide state in `lib/app/viewmodels/`.
- Keep feature-specific state inside that feature's `presentation/`.
- Prefer `data/` for API adapters, services, and simple feature models.
- Prefer `presentation/screens/`, `presentation/widgets/`, and `presentation/viewmodels/` or `presentation/controllers/` for UI-facing code.
- Keep shared widgets in `lib/core/widgets/` only when they are truly reused across features.

## Naming rules

- Use `snake_case` for all Dart files.
- Name screen files with a `_screen.dart` suffix.
- Name service files with a `_service.dart` suffix.
- Name controller files with a `_controller.dart` suffix.
- Name state files with a `_state.dart` suffix.
- Keep generic filenames like `endpoints.dart` out of shared modules when a domain-specific name is clearer.

## State management

- Use Riverpod controllers for new screen-level work.
- Keep legacy `ChangeNotifier` view models isolated and migrate them feature by feature.
- Avoid placing feature state in `app/` unless it is truly app-global.
