> [!NOTE]
> **Why use `coverde optimize-tests`?**
>
> The `optimize-tests` command gathers all your Dart test files into a single "optimized" test entry point. This can lead to much faster test execution, especially in CI/CD pipelines or large test suites. By reducing the Dart VM spawn overhead and centralizing test discovery, it enables more efficient use of resources.
>
> For more information, see the [flutter/flutter#90225](https://github.com/flutter/flutter/issues/90225).
