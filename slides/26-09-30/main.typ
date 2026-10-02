#import "@preview/touying:0.8.0": *
#import themes.metropolis: *
#import "@preview/numbly:0.1.0": numbly
#import "@preview/pinit:0.2.2": *

#show: metropolis-theme.with(
  aspect-ratio: "16-9",
  config-info(
    title: [Intelligent Agents],
    author: [Your Name],
    date: datetime.today(),
  ),
  footer-progress: false,
)

#set text(
  font: (
    (name: "Inter", covers: "latin-in-cjk"),
    "Noto Sans CJK SC",
  ),
  weight: "regular",
  size: 20pt,
  lang: "zh",
  region: "cn",
)

// 代码字体
#show raw: set text(
  font: (
    "Maple Mono Normal NF",
  ),
)

#show math.equation: set text(font: "New Computer Modern Math")

// 中西文混排：不加 show 规则，汉字与西文同为 20pt、共用基线（原因见 slides/template）。

#set heading(numbering: numbly("{1}.", default: "1.1"))

// ========== Title Slide ==========
#title-slide()

// ========== Outline ==========
= Outline <touying:hidden>
#outline(title: none, indent: auto, depth: 1)

// ========== Section 1 ==========
= What is an Agent?

== Definition

An *agent* is anything that can be viewed as perceiving its environment through *sensors* and acting upon that environment through *actuators*.

#text(size: 0.9em)[agent 就是一个能够通过传感器感知环境，并通过执行器对环境采取行动的实体。]

#pause

Key characteristics:
- *Autonomy*: operates without continuous human intervention
- *Reactivity*: responds to environmental changes
- *Proactivity*: takes initiative to achieve goals
- *Social ability*: interacts with other agents or humans

== Simple Agent Architecture

#align(center)[
  #block(width: 80%)[
    Environment  →  Sensors  →  Agent Function  →  Actuators  →  Environment
  ]
]

#pause

The *agent function* maps percept sequences to actions.

== The PEAS Framework

PEAS is a practical way to specify an intelligent agent before implementation:

#slide[
  #set text(size: 18pt)
  #table(
    columns: 2,
    inset: 0.7em,
    stroke: 0.5pt + luma(180),
    fill: (x, y) => if y == 0 { luma(225) } else { none },
    [*Dimension*], [*Question*],
    [Performance], [How do we measure success?],
    [Environment], [Where does the agent operate?],
    [Actuators], [How can it change the world?],
    [Sensors], [What can it observe?],
  )
]

#pause

For an autonomous taxi, PEAS might be: safety and travel time; roads and traffic; steering and braking; cameras, GPS, and lidar.

== Rationality and Bounded Rationality

An agent is *rational* when it chooses the action that maximizes expected performance, given:

- the percept sequence available so far;
- its prior knowledge of the environment;
- the actions it can execute; and
- the performance measure.

#pause

Perfect rationality is rarely possible: observations are noisy, computation is limited, and the future is uncertain. Real systems therefore optimize under resource constraints.

// ========== Section 2 ==========
= Types of Agents

== Four Classic Types (Russell & Norvig)

#slide[
  #set text(size: 18pt)
  #grid(
    columns: 2,
    gutter: 1.2em,
    [
      *1. Simple Reflex Agents*
      - Condition-action rules
      - No memory of past
      - Fast but limited
    ],
    [
      *2. Model-Based Reflex Agents*
      - Maintain internal state
      - Track unobservable aspects
      - Better in partially observable environments
    ],

    [
      *3. Goal-Based Agents*
      - Consider future outcomes
      - Search & planning
      - Decide actions that achieve goals
    ],
    [
      *4. Utility-Based Agents*
      - Maximize expected utility
      - Handle trade-offs
      - Prefer better outcomes among many goals
    ],
  )
]

== Learning Agents

A modern agent often includes a *learning element*:

#align(center)[
  #block(fill: luma(240), inset: 1em, radius: 6pt, width: 85%)[
    Performance Element + Critic + Learning Element + Problem Generator
  ]
]

#pause

This allows the agent to improve its behavior over time from experience.

== Environment Properties

The environment determines which agent design is appropriate:

#slide[
  #grid(
    columns: 2,
    gutter: 1em,
    [*Observable vs. partially observable*\ Can the agent see the complete state?],
    [*Deterministic vs. stochastic*\ Does an action have a predictable result?],

    [*Episodic vs. sequential*\ Do earlier actions affect later decisions?],
    [*Static vs. dynamic*\ Can the world change while the agent thinks?],

    [*Discrete vs. continuous*\ Are states, time, and actions countable?],
    [*Single-agent vs. multi-agent*\ Are other decision makers present?],
  )
]

#pause

The same algorithm can behave very differently when these assumptions change. Explicitly stating them prevents hidden design failures.

// ========== Section 3 ==========
= Decision Making Under Uncertainty

== Markov Decision Processes

Many sequential decision problems can be modeled as an MDP:

#align(center)[
  $ M = (S, A, P, R, gamma) $
]

- $S$: states, $A$: available actions
- $P(s' | s, a)$: transition dynamics
- $R(s, a)$: immediate reward
- $gamma$: discount factor, with $0 <= gamma <= 1$

#pause

The Markov property says that the current state contains all information needed to predict the future:

#align(center)[
  $ P(s_(t+1) | s_t, a_t, s_(t-1), dots) = P(s_(t+1) | s_t, a_t) $
]

== Value, Policy, and Return

A *policy* $pi(a | s)$ maps states to actions. The discounted return is:

#align(center)[
  $ G_t = sum_(k=0)^infinity gamma^k r_(t+k+1) $
]

The state-value function estimates the expected return under a policy:

#align(center)[
  $ V^pi(s) = E_pi[G_t | s_t = s] $
]

#pause

Learning becomes a search for a policy that produces high long-term value, not merely a sequence of locally good actions.

== The Reinforcement Learning Loop

#align(center)[
  #block(width: 90%, inset: 1em, fill: luma(240), radius: 6pt)[
    State $s_t$  →  Agent chooses $a_t$  →  Environment returns $r_(t+1)$ and $s_(t+1)$
  ]
]

#pause

At every step, the agent balances:

- *exploration*: try uncertain actions to learn more;
- *exploitation*: choose actions already known to work well.

This exploration-exploitation tension is central to online learning.

// ========== Section 3 ==========
= Intelligent Agents in Practice

== Multi-Agent Systems (MAS)

#slide[
  - Multiple interacting agents
  - Cooperation, competition, or negotiation
  - Applications: traffic control, smart grids, distributed sensing
]

== Large Language Model Agents

Modern LLM-based agents typically combine:

#pause

- *Reasoning* (Chain-of-Thought, ReAct, Tree of Thoughts)
- *Tool use* (APIs, search, code execution)
- *Memory* (short-term context + long-term vector stores)
- *Planning* (decompose tasks into sub-goals)

#pause

Popular frameworks: LangChain, AutoGen, CrewAI, Semantic Kernel, etc.

== A Tool-Using Agent Workflow

#slide[
  #set text(size: 18pt)
  #grid(
    columns: 4,
    gutter: 0.6em,
    [*1. Observe*\ Read the task and context],
    [*2. Plan*\ Decompose the goal],
    [*3. Act*\ Call tools and APIs],
    [*4. Reflect*\ Check results and revise],
  )
]

#pause

The language model is not the whole agent. Reliable behavior comes from the loop around it: typed tools, state management, validation, retries, and explicit stopping rules.

== Grounding and Tool Contracts

Tools turn abstract reasoning into verifiable actions:

#slide[
  ```json
  {
    "name": "lookup_weather",
    "arguments": {
      "city": "Shanghai",
      "date": "2026-09-29"
    }
  }
  ```
]

#pause

A robust tool interface should define:

- a narrow purpose and typed inputs;
- predictable outputs and error states;
- permission boundaries and audit logs;
- timeouts, retries, and idempotency where needed.

== Evaluating Agentic Systems

Evaluation should measure more than whether the final answer sounds plausible:

- *Task success*: did the agent achieve the user goal?
- *Grounding*: are claims supported by observations or sources?
- *Efficiency*: how many tokens, tool calls, and seconds were used?
- *Robustness*: does it recover from malformed or unavailable tools?
- *Safety*: does it respect permissions and refuse unsafe actions?

#pause

Trace-based evaluation makes failures diagnosable: inspect the observation, decision, tool call, result, and final response as one trajectory.

== Key Challenges

- *Hallucination* and reliability
- *Long-horizon planning*
- *Grounding* in real environments
- *Safety & alignment*
- *Evaluation* of open-ended behavior

== Design Principles

When building an agent, prefer:

#slide[
  #grid(
    columns: 2,
    gutter: 1em,
    [*Small action spaces*\ Make each tool easy to validate.],
    [*Explicit state*\ Store important decisions outside the prompt.],

    [*Reversible actions*\ Preview or stage high-impact changes.],
    [*Human checkpoints*\ Ask for approval at meaningful risk boundaries.],
  )
]

#slide[
  #grid(
    columns: (3fr, 2fr),       // 左右平分；如需图宽文窄可设为 (3fr, 2fr) 或 (60%, 40%)
    gutter: 1.5em,             // 左右间距
    align: horizon,            // 垂直居中对齐（若希望顶部对齐可改为 top）
    
    // 左侧：图片
    image("src/BookMap.png", width: 100%),
    
    // 右侧：文字内容
    [
      *这里写标题或重点*
      
      - 第一点说明内容
      - 第二点说明内容
      - 第三点说明内容
    ]
  )
]





// ========== Section 4 ==========
= Summary

== Takeaways


- An agent perceives and acts to #pin(1)achieve goals#pin(2)
- Classic taxonomy: reflex → model-based → goal-based → utility-based
- Learning agents improve through experience
- Modern AI agents combine #pin(3)LLMs + tools + memory + planning#pin(4)
- Multi-agent systems enable complex collaborative behaviors


// 蓝色标注：achieve goals
#pinit-highlight(1, 2, fill: rgb(0, 180, 255).transparentize(65%))
#pinit-point-from(
  fill: rgb(0, 180, 255),
  pin-dx: 0em,
  pin-dy: 0.35em,
  body-dx: 8pt,
  body-dy: 0.2em,
  offset-dx: 12pt,
  offset-dy: 1.6em,
  2,
  [
    #set text(fill: rgb(0, 180, 255), size: 0.82em, weight: "medium")
    Core definition of an agent
  ],
)

// 紫色标注：LLMs + tools + memory + planning
#pinit-highlight(3, 4, fill: rgb(150, 90, 170).transparentize(65%))
#pinit-point-from(
  fill: rgb(150, 90, 170),
  pin-dx: 0em,
  pin-dy: 0.35em,
  body-dx: 8pt,
  body-dy: 0.2em,
  offset-dx: 12pt,
  offset-dy: 1.6em,
  4,
  [
    #set text(fill: rgb(150, 90, 170), size: 0.82em, weight: "medium")
    Key components of modern AI agents
  ],
)

#focus-slide[
  Thank you!

  Questions?
]

// tortrixx/slides · 仓库约定见 AGENTS.md
