import js from '@eslint/js';
import reactHooks from 'eslint-plugin-react-hooks';
import globals from 'globals';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  { ignores: ['dist', 'public'] },
  {
    extends: [js.configs.recommended, ...tseslint.configs.strict],
    files: ['**/*.{ts,tsx}'],
    languageOptions: { ecmaVersion: 2022, globals: { ...globals.browser, ...globals.worker } },
    plugins: { 'react-hooks': reactHooks },
    rules: {
      ...reactHooks.configs.recommended.rules,
      'no-restricted-imports': [
        'error',
        {
          patterns: [
            { group: ['react', 'maplibre-gl', '../ui/*', '../infrastructure/*'], message: 'El dominio no depende de UI ni infraestructura.' },
          ],
        },
      ],
    },
  },
  {
    // La regla de dependencias solo restringe al dominio
    files: ['src/ui/**', 'src/infrastructure/**', 'src/application/**', 'src/main.tsx', 'src/**/*.test.ts'],
    rules: { 'no-restricted-imports': 'off' },
  },
  {
    files: ['src/**/*.test.ts'],
    rules: { '@typescript-eslint/no-non-null-assertion': 'off' },
  },
);
