# Mermaid Examples

## Software Architecture

```mermaid
graph LR
    Client --> API
    API --> DB[Database]
    API --> Auth[Authentication]
    Client --> UI[User Interface]
```

## Service Website Architecture

```mermaid
graph TD
    Dev[👨‍💻 Developer] --> GitHub[📁 GitHub Repository]
    GitHub -->|Triggers| Validate[🔍 Validate]

    subgraph "🤖 GitHub Actions CI/CD Pipeline"
        Validate --> Security[🔐 Security]
        Security --> Test[🧪 Test]
        Test --> Build[🏗️ Build]
        Build --> Preview[✅ Deploy Preview]
        Preview --> Deploy[🚀 Deploy]
    end

    Deploy --> Netlify[🌐 Netlify Deployment]
    Netlify --> WebApp[🚀 Astro Web App]
    User[👤 User] --> WebApp
    WebApp --> Form[/📝 Contact Form Submission/]
    WebApp --> Phone[📞 Phone Call]
    WebApp --> Email[📧 Email]
    Form --> NetlifyForms[(💾 Netlify Forms Backend)]
    NetlifyForms --> Function{{⚙️ Serverless Function}}
    Function --> ZohoCRM[[💼 Zoho CRM]]
```

## Process

```mermaid
graph TD
    A[Start] --> B{Decision?}
    B -- Yes --> C[Action 1]
    B -- No --> D[Action 2]
    C --> E[End]
    D --> E[End]
```

## Sequence

```mermaid
sequenceDiagram
    Alice->>Bob: Hello Bob, how are you?
    Bob-->>Alice: I am good, thanks!
    Alice->>John: Hi John, are you OK?
    John-->>Alice: Yes, all good!
```

## Class

```mermaid
classDiagram
    Animal <|-- Duck
    Animal <|-- Fish
    Animal <|-- Zebra
    class Animal{
        +int age
        +String gender
        +isMammal()
        +mate()
    }
    class Duck{
        +String beakColor
        +swim()
        +quack()
    }
    class Fish{
        -int sizeInFeet
        -canEat()
    }
```

## State

```mermaid
stateDiagram
    [*] --> LoggedOut
    LoggedOut --> LoggedIn: User logs in
    LoggedIn --> LoggedOut: User logs out
    LoggedIn --> ShoppingCart: Selects item
    ShoppingCart --> Checkout: Proceeds to checkout
    Checkout --> [*]: Purchase complete
```

## Entity-Relationship (ER)

```mermaid
erDiagram
    CUSTOMER ||--o{ ORDER : places
    ORDER ||--|{ LINE-ITEM : contains
    CUSTOMER {
        string name
        string address
    }
    ORDER {
        int orderNumber
        string date
    }
    LINE-ITEM {
        string productCode
        int quantity
    }
```

## Gantt

```mermaid
gantt
    dateFormat  YYYY-MM-DD
    title Project Timeline
    section Planning
    Task A           :a1, 2024-09-20, 3d
    Task B           :after a1  , 5d
    section Execution
    Task C           :2024-09-25  , 4d
    Task D           :2024-09-29  , 3d
```

## Pie Chart

```mermaid
pie
    title Language distribution
    "JavaScript" : 40
    "Python" : 30
    "TypeScript" : 20
    "Other" : 10
```

## User Journey

```mermaid
journey
    title User Journey Map
    section Signup
      User: 5: Signs up
      System: 2: Sends confirmation email
    section Onboarding
      User: 4: Completes profile
      System: 3: Sets up user preferences
    section Usage
      User: 5: Starts using the product
      System: 5: Tracks behavior
```

## Requirements
TODO: syntax error

```mermaid
requirementDiagram
```

## Git

```mermaid
gitGraph
    commit
    branch develop
    commit
    branch feature-x
    commit
    checkout develop
    merge feature-x
    commit
```

## Mind Map

```mermaid
mindmap
  root((Mind Mapping))
    Creative Thinking
      Brainstorming
      Idea Generation
    Organization
      Structured Thoughts
      Categorization
```

## Timeline

```mermaid
timeline
    title Development Timeline
    2022 : Project concept
    2023 : Initial MVP release
    2024 : Public launch
```

## Quadrant

```mermaid
graph TD
    %% Define the quadrants
    A1["High Impact, Low Probability"]
    A2["High Impact, High Probability"]
    B1["Low Impact, Low Probability"]
    B2["Low Impact, High Probability"]

    %% Create a grid by linking horizontally and vertically
    A1 --> A2
    B1 --> B2
    A1 --> B1
    A2 --> B2
```

## Decision Tree

```mermaid
graph TD
    Start --> Decision1{Is it raining?}
    Decision1 -- Yes --> Action1[Take umbrella]
    Decision1 -- No --> Action2[Leave umbrella]
    Action1 --> End
    Action2 --> End
```
