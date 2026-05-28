import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Uso: dart run tool/check_coverage.dart <lcov.info> '
      '[--global-min=N] [--domain-min=N]',
    );
    exit(64);
  }

  final file = File(args.first);
  if (!file.existsSync()) {
    stderr.writeln('No existe el reporte de cobertura: ${file.path}');
    exit(66);
  }

  final globalMin = _readMin(args, '--global-min', 60);
  final domainMin = _readMin(args, '--domain-min', 70);
  final records = _parseLcov(
    file.readAsLinesSync(),
  ).where((record) => !_isGenerated(record.source));

  final global = _sum(records);
  final domain = _sum(
    records.where((record) => record.source.contains('/domain/')),
  );

  _printCoverage('Global', global);
  _printCoverage('Domain', domain);

  var failed = false;
  if (global.percent < globalMin) {
    stderr.writeln(
      'Cobertura global ${global.percent.toStringAsFixed(2)}% '
      '< minimo ${globalMin.toStringAsFixed(2)}%',
    );
    failed = true;
  }

  if (domain.linesFound > 0 && domain.percent < domainMin) {
    stderr.writeln(
      'Cobertura domain ${domain.percent.toStringAsFixed(2)}% '
      '< minimo ${domainMin.toStringAsFixed(2)}%',
    );
    failed = true;
  }

  if (failed) {
    exit(1);
  }
}

/// El código generado por build_runner (Drift `.g.dart`, freezed, etc.) no se
/// gatea por cobertura: es derivado, no escrito a mano.
bool _isGenerated(String source) =>
    source.endsWith('.g.dart') || source.endsWith('.freezed.dart');

double _readMin(List<String> args, String name, double fallback) {
  final prefix = '$name=';
  for (final arg in args.skip(1)) {
    if (arg.startsWith(prefix)) {
      return double.parse(arg.substring(prefix.length));
    }
  }
  return fallback;
}

List<_CoverageRecord> _parseLcov(List<String> lines) {
  final records = <_CoverageRecord>[];
  String? source;
  var linesFound = 0;
  var linesHit = 0;

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      source = line.substring(3);
      linesFound = 0;
      linesHit = 0;
    } else if (line.startsWith('LF:')) {
      linesFound = int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      linesHit = int.parse(line.substring(3));
    } else if (line == 'end_of_record' && source != null) {
      records.add(
        _CoverageRecord(
          source: source,
          linesFound: linesFound,
          linesHit: linesHit,
        ),
      );
      source = null;
    }
  }

  return records;
}

_CoverageRecord _sum(Iterable<_CoverageRecord> records) {
  var linesFound = 0;
  var linesHit = 0;

  for (final record in records) {
    linesFound += record.linesFound;
    linesHit += record.linesHit;
  }

  return _CoverageRecord(
    source: '<sum>',
    linesFound: linesFound,
    linesHit: linesHit,
  );
}

void _printCoverage(String label, _CoverageRecord coverage) {
  stdout.writeln(
    '$label coverage: ${coverage.percent.toStringAsFixed(2)}% '
    '(${coverage.linesHit}/${coverage.linesFound})',
  );
}

class _CoverageRecord {
  const _CoverageRecord({
    required this.source,
    required this.linesFound,
    required this.linesHit,
  });

  final String source;
  final int linesFound;
  final int linesHit;

  double get percent {
    if (linesFound == 0) {
      return 100;
    }
    return (linesHit / linesFound) * 100;
  }
}
