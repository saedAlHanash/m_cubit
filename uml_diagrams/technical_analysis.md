# M_Cubit Technical Analysis

This document breaks down the internal workflow and data flow of the `m_cubit` library.

## Data Flow Lifecycle

The data flow in `m_cubit` follows a caching-first, unidirectional pattern. It ensures that the UI is always reactive to the latest state, whether it comes from a local cache or a remote server.

### 1. Cubit Initialization

- **Instantiation**: A class that extends `MCubit<S>` (where `S` is a class extending `AbstractState`) is created.
- **Initial State**: The constructor of `MCubit` is called with an initial state (e.g., `MyState(result: [], statuses: CubitStatuses.init)`). This sets the default state before any operations occur.
- **Dependency Injection**: The Cubit instance is typically provided to the widget tree using a `BlocProvider`, making it accessible to UI components.

### 2. Event Triggering from the UI

- **User Action**: A user interacts with a UI element (e.g., presses a button, loads a screen).
- **Method Invocation**: An event handler in the UI calls a public method on the Cubit instance. This method is designed to fetch data, for example, `myCubit.fetchData()`.

### 3. State Management within the Cubit (`getDataAbstract`)

The core of the logic resides within the `getDataAbstract` method.

- **Cache Check (`checkCashed`)**:
    1. The method first attempts to load data from the local cache using `getListCached` or `getDataCached`.
    2. It emits a state with `CubitStatuses.loading` to notify the UI that a data fetch is in progress, while potentially displaying the already cached data.
    3. The `CachingService.needGetData()` method is called to check if the cached data is still valid or has expired based on the configured `timeInterval`.
    4. If the cache is valid (`NeedUpdateEnum.no`), the process stops here, and the UI will have received the cached data.

- **API Fetch**:
    1. If the cache is empty or stale, `getDataAbstract` proceeds to invoke the `getDataApi` function passed to it.
    2. This function is responsible for making the network request to the server.

- **Handling the Response & State Emission (`emit`)**:
    1. **On Success**:
        - The new data received from the API is saved to the local cache via `saveData()`.
        - The Cubit calls `emit()` with a new state object containing the fetched data and a status of `CubitStatuses.done`.
    2. **On Failure**:
        - If the API call fails, the Cubit calls `emit()` with a new state object containing the error details and a status of `CubitStatuses.error`.

### 4. UI Reaction to State Changes

- **Listening**: UI components like `BlocBuilder` or `BlocListener` are subscribed to the Cubit's state stream.
- **Rebuild**: When `emit()` is called, these widgets receive the new state object and rebuild themselves.
- **Conditional Rendering**: The UI uses the properties of the state object (`state.statuses`, `state.result`, `state.error`) to render the appropriate component:
    - `CubitStatuses.loading`: Show a progress indicator.
    - `CubitStatuses.done`: Display the data from `state.result`.
    - `CubitStatuses.error`: Show an error message from `state.error`.
    - `isDataEmpty`: Show a "No Data" message if the result is an empty list.
