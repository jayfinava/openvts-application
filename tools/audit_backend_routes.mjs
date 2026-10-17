// Read-only route inventory against a supplied checkout. This checks path
// presence, not runtime authorization, DTO compatibility or HTTP methods.
import fs from 'node:fs';
import path from 'node:path';

const backend = process.argv[2];
if (!backend) throw new Error('Usage: node tools/audit_backend_routes.mjs <backend/src>');
function files(dir, suffix) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const file = path.join(dir, entry.name);
    return entry.isDirectory() ? files(file, suffix) : file.endsWith(suffix) ? [file] : [];
  });
}
function normalize(value) {
  return `/${value}`.replace(/\/+/g, '/').replace(/\/$/, '') || '/';
}
function template(value) {
  return normalize(value.replace(/\$\{[^}]+\}/g, ':param').replace(/\$\w+/g, ':param').split('?')[0]);
}
const routes = [];
for (const file of files(backend, '.controller.ts')) {
  const source = fs.readFileSync(file, 'utf8');
  const controller = source.match(/@Controller\(\s*(?:['"`]([^'"`]*)['"`]\s*)?\)/);
  if (!controller) continue;
  const prefix = controller[1] ?? '';
  for (const match of source.matchAll(/@(Get|Post|Put|Patch|Delete)\(\s*(?:['"`]([^'"`]*)['"`]\s*)?\)/g)) {
    routes.push({ method: match[1].toUpperCase(), path: normalize(`${prefix}/${match[2] ?? ''}`), file });
  }
}
const dart = fs.readFileSync('lib/core/api/api_endpoints.dart', 'utf8');
const usages = files('lib', '.dart').filter(file => !file.endsWith('api_endpoints.dart'))
  .map(file => fs.readFileSync(file, 'utf8')).join('\n');
const checked = [];
const endpointPaths = new Map();
for (const role of ['Auth', 'Public', 'Superadmin', 'Admin', 'User']) {
  const body = dart.match(new RegExp(`class _${role}Endpoints \\{([\\s\\S]*?)(?=\\nclass |$)`))?.[1] ?? '';
  for (const match of body.matchAll(/String\s+(?:get\s+)?(\w+)[\s\S]*?=>\s*(['"])(\/[^\n]*?)\2\s*;/g)) {
    const name = `ApiEndpoints.${role.toLowerCase()}.${match[1]}`;
    const reference = new RegExp(`${name.replace(/\./g, '\\.')}\\b`);
    if (!reference.test(usages) || match[3].includes("'")) continue;
    const target = template(match[3]);
    endpointPaths.set(name, target);
    const parts = target.split('/');
    const candidates = routes.filter(route => {
      const actual = route.path.split('/');
      return actual.length === parts.length && actual.every((part, i) => part.startsWith(':') || parts[i].startsWith(':') || part === parts[i]);
    });
    checked.push({ name, path: target, methods: [...new Set(candidates.map(r => r.method))] });
  }
}
// Resolve simple aliases as well as direct endpoint builders when a service
// supplies one as the first HTTP argument. Dynamic request helpers remain a
// declared limitation; a passing inventory is not a runtime API certification.
for (const role of ['Auth', 'Public', 'Superadmin', 'Admin', 'User']) {
  const body = dart.match(new RegExp(`class _${role}Endpoints \\{([\\s\\S]*?)(?=\\nclass |$)`))?.[1] ?? '';
  for (const match of body.matchAll(/^\s*String\s+(?:get\s+)?(\w+)(?:\([^;]*?\))?\s*=>\s*(\w+)\([^;]*\);/gm)) {
    const prefix = `ApiEndpoints.${role.toLowerCase()}.`;
    if (endpointPaths.has(prefix + match[2])) endpointPaths.set(prefix + match[1], endpointPaths.get(prefix + match[2]));
  }
}
const methodChecks = [];
function matchesRoute(target, route) {
  const actual = route.path.split('/'), parts = target.split('/');
  return actual.length === parts.length && actual.every((part, i) => part.startsWith(':') || parts[i].startsWith(':') || part === parts[i]);
}
for (const file of files('lib', '.dart')) {
  const source = fs.readFileSync(file, 'utf8');
  const expression = /\b(?:_apiClient|apiClient|_api|api|_dio|dio)\.(get|post|put|patch|delete)(?:<[^;{}]+?>)?\(\s*(ApiEndpoints\.\w+\.\w+|(['"])(\/[^'"\n]*)\3)/g;
  for (const match of source.matchAll(expression)) {
    const target = match[4] ? template(match[4]) : endpointPaths.get(match[2]);
    if (!target) continue;
    const method = match[1].toUpperCase();
    methodChecks.push({ method, path: target, file: file.replaceAll('\\', '/'),
      line: source.slice(0, match.index).split('\n').length,
      matches: routes.some(route => route.method === method && matchesRoute(target, route)) });
  }
}
console.log(JSON.stringify({ controllers: new Set(routes.map(r => r.file)).size,
  backendRoutes: routes.length, checkedUsedEndpointBuilders: checked.length,
  missing: checked.filter(row => row.methods.length === 0),
  checkedHttpMethodCalls: methodChecks.length,
  methodOrPathMismatches: methodChecks.filter(row => !row.matches),
  limitations: 'Static endpoint builders and direct HTTP arguments only; excludes unresolved dynamic helpers and does not certify DTOs, authorization or deployed behavior.' }, null, 2));
