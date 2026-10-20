{{flutter_js}}
{{flutter_build_config}}

// Match each compiled app to its build while retiring the deprecated offline worker.
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) build.mainJsPath += '?v=' + {{flutter_service_worker_version}};
}
_flutter.loader.load();
