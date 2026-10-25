import 'package:coverde/src/features/reporting/failures/coverage_report_failure.dart';
import 'package:liquify/parser.dart' as liquid;

/// Fails when [source] reads a top-level Liquid name that is not in [known].
///
/// [readTemplate] loads `{% render %}` partials. Render arguments are the only
/// names visible inside a partial.
void assertKnownTemplateVariables({
  required String source,
  required Set<String> known,
  required String Function(String relativePath) readTemplate,
  Set<String>? rendering,
}) {
  final stack = rendering ?? <String>{};
  _checkNodes(liquid.parseInput(source), {...known}, readTemplate, stack);
}

void _checkNodes(
  List<liquid.ASTNode> nodes,
  Set<String> declared,
  String Function(String relativePath) readTemplate,
  Set<String> rendering,
) {
  for (final node in nodes) {
    if (node is liquid.Variable) {
      _checkExpression(node.expression, declared, readTemplate, rendering);
    } else if (node is liquid.Tag) {
      _checkTag(node, declared, readTemplate, rendering);
    }
  }
}

void _checkTag(
  liquid.Tag tag,
  Set<String> declared,
  String Function(String relativePath) readTemplate,
  Set<String> rendering,
) {
  switch (tag.name) {
    case 'for':
      final binary = tag.content.whereType<liquid.BinaryOperation>().first;
      final variable = binary.left;
      if (variable is! liquid.Identifier) {
        throw const CoverageTemplateRenderFailure(
          readableMessage: 'A for loop must declare a variable.',
        );
      }
      _checkExpression(binary.right, declared, readTemplate, rendering);
      _checkNodes(
        tag.body,
        {...declared, variable.name, 'forloop'},
        readTemplate,
        rendering,
      );
    case 'assign':
      final assignment = _assignment(tag);
      if (assignment == null || assignment.variable is! liquid.Identifier) {
        throw const CoverageTemplateRenderFailure(
          readableMessage: 'An assign tag must declare a variable.',
        );
      }
      _checkExpression(assignment.value, declared, readTemplate, rendering);
      declared.add((assignment.variable as liquid.Identifier).name);
    case 'render':
      final partial = tag.content.whereType<liquid.Literal>().first.value;
      if (partial is! String) {
        throw const CoverageTemplateRenderFailure(
          readableMessage: 'A render tag requires a template path.',
        );
      }
      final partialNames = <String>{};
      for (final argument in tag.content.whereType<liquid.NamedArgument>()) {
        _checkExpression(argument.value, declared, readTemplate, rendering);
        partialNames.add(argument.identifier.name);
      }
      if (!rendering.add(partial)) return;
      try {
        assertKnownTemplateVariables(
          source: readTemplate(partial),
          known: partialNames,
          readTemplate: readTemplate,
          rendering: rendering,
        );
      } finally {
        rendering.remove(partial);
      }
    default:
      for (final child in tag.content) {
        _checkExpression(child, declared, readTemplate, rendering);
      }
      _checkNodes(tag.body, declared, readTemplate, rendering);
  }
}

liquid.Assignment? _assignment(liquid.Tag tag) {
  for (final node in tag.content) {
    if (node is liquid.Assignment) return node;
  }
  return null;
}

const _literalNames = {'null', 'nil', 'true', 'false', 'blank', 'empty'};

void _checkExpression(
  liquid.ASTNode node,
  Set<String> declared,
  String Function(String relativePath) readTemplate,
  Set<String> rendering,
) {
  if (node is liquid.ArrayAccess) {
    _checkExpression(node.array, declared, readTemplate, rendering);
    _checkExpression(node.key, declared, readTemplate, rendering);
    return;
  }
  if (node is liquid.Identifier) {
    if (!declared.contains(node.name) && !_literalNames.contains(node.name)) {
      throw CoverageTemplateRenderFailure(
        readableMessage: 'Unknown template variable `${node.name}`.',
      );
    }
    return;
  }
  if (node is liquid.MemberAccess) {
    _checkExpression(node.object, declared, readTemplate, rendering);
    for (final member in node.members) {
      if (member is liquid.ArrayAccess) {
        _checkExpression(member.key, declared, readTemplate, rendering);
      }
    }
    return;
  }
  if (node is liquid.FilteredExpression) {
    _checkExpression(node.expression, declared, readTemplate, rendering);
    for (final filter in node.filters) {
      _checkExpression(filter, declared, readTemplate, rendering);
    }
    return;
  }
  if (node is liquid.Filter) {
    for (final argument in node.arguments) {
      _checkExpression(argument, declared, readTemplate, rendering);
    }
    return;
  }
  if (node is liquid.Assignment) {
    _checkExpression(node.value, declared, readTemplate, rendering);
    return;
  }
  if (node is liquid.BinaryOperation) {
    _checkExpression(node.left, declared, readTemplate, rendering);
    _checkExpression(node.right, declared, readTemplate, rendering);
    return;
  }
  if (node is liquid.GroupedExpression || node is liquid.UnaryOperation) {
    final expression = node is liquid.GroupedExpression
        ? node.expression
        : (node as liquid.UnaryOperation).expression;
    _checkExpression(expression, declared, readTemplate, rendering);
    return;
  }
}
