---
title: MarkDwain Feature Tour
author: Sample Author
tags: [markdown, demo]
---

# MarkDwain Feature Tour

This file exercises every feature. Front matter above should be a collapsed block.

[Jump to Code](#code) · [Jump to the end](#the-end)

## Text

**Bold**, *italic*, ~~strikethrough~~, `inline code`, and an autolink: https://example.com.

> A blockquote with a second line
> and **formatting**.

---

1. Ordered
   - Nested bullet
     - Deeper bullet
2. Second item

A footnote reference.[^1]

[^1]: The footnote text.

## Tables

| Language | Typing  | Year |
|----------|---------|-----:|
| Swift    | Static  | 2014 |
| Python   | Dynamic | 1991 |
| Go       | Static  | 2009 |

## Task lists

- [x] Render checkboxes
- [x] Keep them read-only
- [ ] Take over the world

## Code

```swift
struct Greeter {
    func greet(_ name: String) -> String { "Hello, \(name)!" }
}
```

```python
def fib(n):
    return n if n < 2 else fib(n - 1) + fib(n - 2)
```

```javascript
const sum = (...xs) => xs.reduce((a, b) => a + b, 0);
```

```bash
echo "hello" | tr a-z A-Z
```

```json
{"name": "MarkDwain", "readonly": true}
```

## Images

A relative image (should display):

![MarkDwain icon](images/sample.png)

<img src="images/sample.png" width="96" alt="raw html image">

<details><summary>Raw HTML details (click)</summary>

Works because HTML is allowed (but sanitized: <script>alert('no')</script> is stripped).

</details>

## Links

- Relative Markdown link: [other.md](other.md)
- Relative link with anchor: [Target Section in other.md](other.md#target-section)
- External: [Example](https://example.com)
- Email: [mail](mailto:someone@example.com)
- Non-Markdown local file: [sample image](images/sample.png)

## Filler Section 1

Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.

### Details 1.1

More text so the table of contents has something to track while scrolling.

## Filler Section 2

Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.

### Details 2.1

More text so the table of contents has something to track while scrolling.

## Filler Section 3

Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.

### Details 3.1

More text so the table of contents has something to track while scrolling.

## Filler Section 4

Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.

### Details 4.1

More text so the table of contents has something to track while scrolling.

## Filler Section 5

Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.

### Details 5.1

More text so the table of contents has something to track while scrolling.

## Filler Section 6

Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.

### Details 6.1

More text so the table of contents has something to track while scrolling.

## Filler Section 7

Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.

### Details 7.1

More text so the table of contents has something to track while scrolling.

## Filler Section 8

Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.

### Details 8.1

More text so the table of contents has something to track while scrolling.

## Filler Section 9

Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.

### Details 9.1

More text so the table of contents has something to track while scrolling.

## Filler Section 10

Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.

### Details 10.1

More text so the table of contents has something to track while scrolling.

## Filler Section 11

Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.

### Details 11.1

More text so the table of contents has something to track while scrolling.

## Filler Section 12

Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.

### Details 12.1

More text so the table of contents has something to track while scrolling.


## The End

You reached the end.
