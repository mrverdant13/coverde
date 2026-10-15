<details>
<summary>Inline Transformations</summary>

#### Inline Transformations

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

</details>

<details>
<summary>Preset Usage</summary>

#### Preset Usage

Given the following `coverde.yaml` configuration:

```yaml
# coverde.yaml

transformations:
  implementation-without-generated:
    - type: keep-by-glob
      glob: "lib/**"
    - type: skip-by-glob
      glob: "**/*.g.dart"
```

Running:

```sh
$ coverde transform \
  --transformations relative="/packages/my_package/" \
  --transformations preset=implementation-without-generated \
  --transformations keep-by-coverage="lte|80"
```

Is equivalent to the [Inline Transformations](#inline-transformations) example.

</details>

<details>
<summary>Preset from another file</summary>

#### Preset from another file

A plain `preset` value is a name in the working directory's `coverde.yaml`. A YAML map with `file` loads that name from another file. Quote a path or name that contains `:` or `#`.

```sh
$ coverde transform \
  --transformations 'preset={file: ../coverde.yaml, name: ci-workflow}'
```

The same preset can be cited from a package `coverde.yaml`. `file` is relative to the yaml file that contains the step:

```yaml
# packages/my_package/coverde.yaml

transformations:
  package:
    - type: preset
      file: ../coverde.yaml
      name: ci-workflow
```

```sh
$ coverde transform --transformations preset=package
```

</details>
