import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption('name', abbr: 'n', help: 'Name of the feature to create')
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show usage information');

  var argResults = parser.parse(arguments);

  if (argResults['help'] as bool || argResults['name'] == null) {
    print('Usage: dart run my_cli_tool.dart -n <name>');
    print(parser.usage);
    exit(0);
  }

  final name = argResults['name'];
  _createFeatureFiles(name);
}

void _createFeatureFiles(String name) {
  final directoryName = name.toLowerCase();

  // Create the folder
  final dir = Directory(directoryName);
  if (dir.existsSync()) {
    print('Directory already exists!');
    exit(1);
  }
  dir.createSync();

  // Create controller file
  final controllerFile =
      File(path.join(directoryName, '${name}_controller.dart'));
  controllerFile.writeAsStringSync(_controllerTemplate(name));

  // Create data source file
  final dataSourceFile =
      File(path.join(directoryName, '${name}_data_source.dart'));
  dataSourceFile.writeAsStringSync(_dataSourceTemplate(name));

  // Create request model file
  final requestModelFile =
      File(path.join(directoryName, '${name}_request.dart'));
  requestModelFile.writeAsStringSync(_requestModelTemplate(name));

  // Create response model file
  final responseModelFile =
      File(path.join(directoryName, '${name}_response.dart'));
  responseModelFile.writeAsStringSync(_responseModelTemplate(name));

  print(
      'Created ${name}_controller.dart, ${name}_data_source.dart, ${name}_request.dart, and ${name}_response.dart inside $directoryName/');
}

String _controllerTemplate(String name) {
  final className = _toPascalCase(name);
  final lowerCamelCase = _toLowerCamelCase(name);
  return '''
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:red_cash_dfs_flutter/module/$name/api/${name}_data_source.dart';
import 'package:red_cash_dfs_flutter/module/$name/api/model/${name}_response.dart';
import 'package:red_cash_dfs_flutter/core/networking/error/failure.dart';
import 'package:red_cash_dfs_flutter/core/networking/safe_api_call.dart';

class ${className}Controller extends StateNotifier<AsyncValue<${className}Response>> {
  Logger get log => Logger(runtimeType.toString());
  final Ref _ref;

  ${className}Controller(this._ref) : super(AsyncData(${className}Response()));

  Future<void> get${className}Info({required String userIdentity}) async {
    try {
      state = const AsyncLoading();

      final response = await _ref.read(${lowerCamelCase}DataSourceProvider).get${className}Info(userIdentity);

      safeApiCall<${className}Response>(response, onSuccess: (response) {
        state = AsyncData(response!);
      }, onError: (code, message) {
        state = AsyncError(message, StackTrace.current);
      });
    } on Failure {
      state = AsyncError("error", StackTrace.current);
    }
  }
}

final ${lowerCamelCase}ControllerProvider = StateNotifierProvider<${className}Controller, AsyncValue<${className}Response>>((ref) {
  return ${className}Controller(ref);
});
''';
}

String _dataSourceTemplate(String name) {
  final className = _toPascalCase(name);
  final lowerCamelCase = _toLowerCamelCase(name);
  return '''
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red_cash_dfs_flutter/module/$name/api/model/${name}_response.dart';
import 'package:red_cash_dfs_flutter/core/di/network_provider.dart';
import 'package:red_cash_dfs_flutter/core/networking/base/base_data_source.dart';
import 'package:red_cash_dfs_flutter/core/networking/base/base_result.dart';
import 'package:red_cash_dfs_flutter/utils/api_urls.dart';

abstract class ${className}DataSource {
  Future<BaseResult<${className}Response>> get${className}Info(String userIdentity);
}

class ${className}DataSourceImpl extends BaseDataSource implements ${className}DataSource {
  ${className}DataSourceImpl(super.dio);

  @override
  Future<BaseResult<${className}Response>> get${className}Info(String userIdentity) {
    return getResult(
      get(ApiUrls.${name}Info, params: {'userIdentity': userIdentity}),
      (response) => ${className}Response.fromJson(response),
    );
  }
}

final ${lowerCamelCase}DataSourceProvider = Provider((ref) {
  final dio = ref.watch(dioProvider);
  return ${className}DataSourceImpl(dio);
});
''';
}

String _requestModelTemplate(String name) {
  final className = _toPascalCase(name);
  return '''
class ${className}Request {
  final String userIdentity;

  ${className}Request({required this.userIdentity});

  Map<String, dynamic> toJson() {
    return {
      'userIdentity': userIdentity,
    };
  }
}
''';
}

String _responseModelTemplate(String name) {
  final className = _toPascalCase(name);
  return '''
class ${className}Response {
  final String info;

  ${className}Response({this.info = ""});

  factory ${className}Response.fromJson(Map<String, dynamic> json) {
    return ${className}Response(
      info: json['info'] as String? ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'info': info,
    };
  }
}
''';
}

String _toPascalCase(String input) {
  return input
      .split('_')
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join();
}

String _toLowerCamelCase(String input) {
  List<String> words = input.split('_');
  String camelCase = words.first;
  camelCase += words
      .skip(1)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join();
  return camelCase;
}
