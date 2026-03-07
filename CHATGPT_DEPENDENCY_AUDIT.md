# ChatGPT Dependency Audit

## Goal
Reduce ChatGPT dependency from core operations to optional brainstorming.

## Dependency categories
- Doctrine dependency
- Process dependency
- Decision dependency
- Technical implementation dependency

## Current state after this pack
- Doctrine dependency: reduced by canonical local docs
- Process dependency: reduced by install, verify, and launcher scripts
- Decision dependency: reduced by explicit gates and rules
- Technical dependency: reduced but still present for novel coding tasks

## Remaining dependencies
1. Novel architecture brainstorming
2. Rare debugging outside documented runbooks
3. Unfamiliar integration design

## Closure plan
- Capture post-mortems into local runbooks after each novel task.
- Convert repeated prompts into deterministic scripts.
- Maintain a local FAQ under BrownEyeCortexData\Runbooks.

## Exit threshold
ChatGPT can be closed when all weekly critical actions are executable from local files alone.
