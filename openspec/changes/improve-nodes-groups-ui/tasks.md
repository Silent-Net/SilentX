# Tasks

## Implementation Phase

- [x] **1. Simplify Nodes protocol display**
  - Removed colored background from protocol badges
  - Changed to plain `.secondary` text color
  - Removed `.background()` and `.padding()` modifiers
  - Removed unused `typeColor` computed property
  - Added separator dot before server address

- [x] **2. Optimize Groups header layout**
  - Removed icon labels (used plain Text instead of Label)
  - Changed spacing from 8 to 6 for tighter layout
  - Made checkmark icon smaller (caption2 size)
  - Keeps information: Type · Node count · Selected

## Verification Phase

- [x] **3. Visual verification**
  - BUILD SUCCEEDED
  - Nodes panel: clean gray protocol text
  - Groups header: compact single-line layout
