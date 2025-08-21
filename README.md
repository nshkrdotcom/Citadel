### **Project Blueprint: Citadel**

**Document Version:** 1.0
**Status:** Proposed

**1. Vision & Mission**

**Project Name:** `Citadel`

**Vision:** To be the command and control layer for the AI-powered enterprise—an indomitable runtime that forges chaotic agentic processes into disciplined, resilient, and effective digital legions.

**Mission:** To provide an unshakeable, OTP-powered fortress for stateful AI agents. `Citadel` imposes order on the chaos of distributed systems, guaranteeing the lifecycle, state integrity, and operational resilience of every agent under its command. It is the architectural high ground from which reliable AI applications are built and governed.

**2. The Problem: The Unruly Frontier of Agentic AI**

The AI frontier is a lawless territory. Developers are creating powerful agents, but they are deploying them into the wild as scattered, fragile scripts. This approach is untenable for production systems, leading to critical vulnerabilities:

*   **Tactical Instability (State Management):** How is an agent's memory and context—its most valuable asset—protected during a crash? A stateless architecture treats this as an afterthought, leading to catastrophic amnesia.
*   **Lack of Discipline (Lifecycle):** When an agent process fails, does it simply vanish? Without a supervisory command structure, a single bug can silently dismantle an entire agent workforce.
*   **Broken Lines of Communication:** In multi-agent systems, how do specialized agents (a "planner," an "executor," a "reviewer") coordinate their actions? Ad-hoc messaging leads to race conditions and brittle, unmaintainable chaos.
*   **Operational Blindness:** Without a central command, developers are fighting blind, unable to see the health, status, and performance of their agent population in real-time.

`Citadel` is the answer. It is not merely a framework; it is the fortified infrastructure that transforms this unruly frontier into a disciplined, strategic asset.

**3. Core Concepts & Fortress Architecture**

`Citadel` is a complete, clustered OTP application designed for strategic dominance. It provides the architectural foundation and command structure for an entire population of AI agents.

**The Core Architectural Primitives:**

*   **Sentinel (`GenServer`):** The individual unit of command. Every agent deployed within `Citadel` is instantiated as a **Sentinel**—a living, stateful, and supervised `GenServer` process. This provides absolute process isolation, ensuring the failure of one Sentinel can never cascade to another.

*   **The Garrison (`Horde.DynamicSupervisor`):** The organizational structure for the Sentinels. The **Garrison** is a distributed supervisor powered by `Horde`. It is responsible for stationing Sentinels across the entire `Citadel` cluster, ensuring they are always running and automatically resurrecting them on healthy nodes if their host node falls.

*   **The Command Registry (`Horde.Registry`):** The distributed intelligence network. The **Command Registry** allows any Sentinel to be addressed by a unique, strategic name (e.g., `{"squadron": "alpha", "unit": 7}`). This enables location-transparent communication: a Sentinel can issue a command to another without knowing its physical location within the cluster's fortifications.

**Diagram: `Citadel` Cluster Command Structure**
```mermaid
graph TD
    subgraph "External Network"
        LB[Load Balancer / Gateway]
    end

    subgraph "The Citadel (Distributed BEAM Cluster)"
        direction LR
        NodeA["Citadel Node A (Bastion)"]
        NodeB["Citadel Node B (Bastion)"]
        NodeC["Citadel Node C (Bastion)"]
        
        subgraph NodeA
            PhoenixEndpoint[Phoenix Endpoint]
            GarrisonA[Garrison Supervisor]
            Sentinel1[Sentinel Process 1]
            Sentinel4[Sentinel Process 4]
        end
        
        subgraph NodeB
            GarrisonB[Garrison Supervisor]
            Sentinel2[Sentinel Process 2]
            Sentinel5[Sentinel Process 5]
        end

        subgraph NodeC
            GarrisonC[Garrison Supervisor]
            Sentinel3[Sentinel Process 3]
            Sentinel6[Sentinel Process 6]
        end
    end
    
    LB --> PhoenixEndpoint
    PhoenixEndpoint -->|Issues Command via Registry| Sentinel3
    Sentinel3 -->|Coordinates with| Sentinel5
    
    linkStyle 2 stroke-width:2px,stroke:red,stroke-dasharray: 5 5;
    linkStyle 3 stroke-width:2px,stroke:blue,stroke-dasharray: 5 5;

    %% Horde's internal command & control network (gossip protocol)
    GarrisonA <--> GarrisonB
    GarrisonB <--> GarrisonC
    GarrisonA <--> GarrisonC
```

**4. Ecosystem Integration: The `Citadel.Sentinel` Protocol**

To enforce discipline and streamline development, `Citadel` defines a formal `behaviour`: the **Sentinel Protocol**. Developers implement this protocol to forge their agent's logic, ensuring it integrates seamlessly into the `Citadel`'s command structure.

```elixir
# lib/my_app/sentinels/analyst_sentinel.ex

defmodule MyApp.Sentinels.AnalystSentinel do
  @behaviour Citadel.Sentinel

  alias AITrace.Context

  # A Sentinel's state represents its memory and current orders.
  defstruct [:id, :mission_objective, :intel, :memory]

  @impl Citadel.Sentinel
  def init(mission_briefing) do
    state = %__MODULE__{id: mission_briefing.id, mission_objective: mission_briefing.objective}
    {:ok, state}
  end

  # `handle_command` is the Sentinel's core operational loop.
  @impl Citadel.Sentinel
  def handle_command(command, state, %Context{} = ctx) do
    # Every command is executed within a fully traced operational theatre.
    
    # 1. Strategic Core (`DSPex`): Determine the next action.
    {:ok, decision, new_ctx} = AITrace.span ctx, "sentinel.strategize" do
      DSPex.execute(MyStrategyModule, %{command: command, intel: state.intel}, context: ctx)
    end
    
    # 2. Rules of Engagement (`Altar`): Execute the action via the command wrapper.
    {:ok, action_report, _final_ctx} = AITrace.span new_ctx, "sentinel.action" do
      Citadel.Arsenal.execute(decision.tool_call, context: new_ctx)
    end
    
    # 3. Update internal state and report back.
    new_state = update_intel(state, action_report)
    report = format_report(action_report)
    {:report, report, new_state}
  end
end
```

**How the Ecosystem Serves the `Citadel`:**

*   **`AITrace` (The Intelligence Network):** The `Citadel` runtime guarantees that every command handled by a Sentinel is fully traced. This provides total battlefield awareness, allowing for forensic analysis of any Sentinel's actions.
*   **`DSPex` (The Sentinel's Strategic Core):** `DSPex` provides the framework for defining the sophisticated, intelligent logic inside each Sentinel, transforming them from simple processes into autonomous strategic actors.
*   **`Altar` (The Rules of Engagement):** The `Citadel.Arsenal` module is the central, governed entry point for all tool use. It uses `Altar` as its foundation to enforce which tools a Sentinel is authorized to use, ensuring disciplined and secure operations.
*   **`Snakepit` (The Expeditionary Force):** When a Sentinel requires specialized, Python-based capabilities, `Citadel.Arsenal` dispatches the task via `Snakepit`. `Snakepit` manages the fleet of Python workers as an expeditionary force, ready to be called upon by any Sentinel in the `Citadel`.

**5. Key Features**

*   **Indomitable Fortress Architecture:** A clustered, self-healing runtime built on OTP and `Horde` that guarantees agent resilience and uptime. Your agent army never sleeps.
*   **Unified Command Network:** Location-transparent messaging allows for complex, inter-agent collaboration across a distributed fleet.
*   **Total Battlefield Awareness:** Every agent's thought process and action is deeply observable via `AITrace`, eliminating operational guesswork.
*   **The Sentinel Protocol:** A disciplined `behaviour` that standardizes agent development, enforcing best practices for state management and logic implementation.
*   **Centralized Arsenal Control:** A single, secure gateway for tool use, powered by `Altar`, ensuring every action is governed, audited, and authorized.
*   **Seamless Integration:** Designed with first-class support for Phoenix, providing real-time command and control of your Sentinel population.

`Citadel` is the definitive answer for developers who are serious about moving beyond AI prototypes. It is the architectural foundation required to build, command, and conquer with large-scale, production-grade AI agent systems.