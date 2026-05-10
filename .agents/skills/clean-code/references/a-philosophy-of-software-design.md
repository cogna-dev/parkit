# Key Takeaways from *A Philosophy of Software Design*

The center of this book is not code style, but a more upstream question: how do you make a system easier to understand and change? Ousterhout treats almost every design judgment as a question of whether complexity goes down.

## Core Claims

- The first goal of good design is to reduce complexity, not to add more structural terminology.
- Complexity is not "there is a lot of code"; it is "future readers must keep too much in mind at once."
- Design should reduce cognitive burden for readers, not merely make local code look tidy.

## Three Direct Symptoms of Complexity

- Change amplification: one requirement change forces edits in many places.
- Cognitive load: to change one place, you must hold too much prerequisite knowledge in your head.
- Unknown unknowns: you do not even know where else the critical facts might be.

## Main Sources of Complexity

- Too many dependencies: one change pulls in many modules.
- Information leakage: callers must understand knowledge that should have stayed inside a module.
- Inconsistency: similar concepts are expressed with different rules, names, or error semantics in different places.

## Key Content

### 1. Deep modules are the central structural test

- A good module should hide a lot of implementation complexity behind a small interface.
- If extracting a module only adds one more name and one more forwarding layer, it is shallow.
- Do not judge a split by file count; judge it by whether callers truly need to know less.

### 2. Push complexity downward, not upward

- Callers should depend on stable interfaces, not on internal flows, sequencing, or directory layout.
- Pass-through methods, mirror APIs, and layers that only forward calls often spread complexity outward instead of containing it.
- A strong abstraction lets users remember the interface without remembering the internal details.

### 3. General-purpose mechanisms are often deeper than specialized ones

- Modules overfitted to the current scenario often have narrow interfaces and short lifespans.
- If one mechanism covers a broader class of problems while keeping the interface simple, it is often deeper than a temporary specialized assembly.
- The second edition emphasizes this more strongly, especially with "General-Purpose Modules are Deeper."

### 4. Do not over-split related logic

- Splitting is only successful when the interface becomes simpler than the original code.
- If two functions must still be read together, remembered together, and reasoned about together, they are entangled, and splitting them can make the design harder to understand.
- More functions do not automatically mean better design; often tightly related logic is clearer when kept together.

### 5. Comments are a design tool, not just a patch

- Interface comments define the contract so callers know what they can rely on.
- Implementation comments capture key facts, design intent, and counterintuitive constraints that are not obvious from the code alone.
- Data-structure comments explain field meaning, lifecycle, and invariants.
- The book's stance is not "more comments is always better," but rather "missing critical comments directly increases complexity."

### 6. Reduce complexity by eliminating special cases

- Special branches, exception protocols, and patchwork fixes quickly increase cognitive cost.
- One important strategy is to "define errors out of existence" by redesigning interfaces, data models, or flows so special handling becomes unnecessary.
- Good design often looks like this: callers never even need to know that a certain category of exception once existed.

### 7. Design requires strategic thinking, not purely tactical progress

- Tactical programming focuses on "finish the immediate change." Strategic programming spends more time thinking about long-term complexity.
- Design is not something you clean up after the code is written; it starts before implementation, when you decide boundaries, interfaces, dependencies, and information hiding.
- The second edition adds "Decide What Matters," emphasizing that you must first identify the factors that truly drive complexity and then focus effort there.

### 8. Consistency is itself a way to reduce complexity

- Consistent naming, error semantics, interface style, and structural conventions reduce the cost of switching context.
- Inconsistency creates extra decisions: does the same kind of thing follow a different rule here again?

## Best Questions to Take Away from the Book

- After this split, do callers truly need to know less, or did they only meet more files?
- Does this interface hide complexity, or only rename it and expose it again?
- Why does one requirement change touch so many places? Has change amplification already appeared?
- Is this code hard to read because the logic is inherently complex, or because critical information is scattered too widely?
- Do we need another layer here, or should tightly coupled logic be pulled back together?

## Public Disagreements with *Clean Code*

- It is more cautious about turning "small functions" into mechanical over-splitting.
- It places more weight on interface and implementation comments as tools for reducing complexity.
- It leans more toward making design judgments first and then implementing, rather than over-tacticalizing the development process.

## Public Sources

- The book page and second-edition notes on John Ousterhout's website
- The author's publications and course/design pages
- The public `johnousterhout/aposd-vs-clean-code` discussion repository
