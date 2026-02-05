```sh
$ coverde transform \
  --transformations relative="/packages/my_package/" \
  --transformations keep-by-glob="lib/**" \
  --transformations skip-by-glob="**/*.g.dart" \
  --transformations keep-by-coverage="lte|80"
```

This transformation chain performs the following steps:
1. Rewrite file paths to be relative to the `/packages/my_package/` directory (useful for monorepos).
2. Keep files that match the `lib/**` glob pattern, i.e. implementation files.
3. Skip files that match the `**/*.g.dart` glob pattern, i.e. generated files.
4. Keep files that have a coverage value less than or equal to 80%.
