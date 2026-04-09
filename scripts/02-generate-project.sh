#!/bin/bash

set -e

WORK_DIR="${1:-/root/test}"
NUM_MODULES="${2:-500}"
NUM_FILES_PER_MODULE="${3:-10}"

echo "=== Generating Heavy Node.js Project ==="
echo "Working directory: $WORK_DIR"
echo "Number of modules: $NUM_MODULES"
echo "Files per module: $NUM_FILES_PER_MODULE"

PROJECT_DIR="$WORK_DIR/heavy-project"
rm -rf "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR"

echo "Creating package.json..."
cat > "$PROJECT_DIR/package.json" << 'EOF'
{
  "name": "heavy-project",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "build": "tsc && vite build",
    "dev": "vite",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "express": "^4.18.2",
    "lodash": "^4.17.21",
    "axios": "^1.6.0",
    "ws": "^8.14.0",
    "uuid": "^9.0.0",
    "moment": "^2.29.4",
    "chart.js": "^4.4.0",
    "date-fns": "^2.30.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "@types/node": "^20.0.0",
    "@types/express": "^4.17.17",
    "@types/lodash": "^4.14.200",
    "@types/uuid": "^9.0.0",
    "@types/ws": "^8.5.0",
    "typescript": "^5.3.0",
    "vite": "^5.0.0",
    "@vitejs/plugin-react": "^4.2.0",
    "esbuild": "^0.19.0",
    "rollup": "^4.9.0",
    "typescript-plugin-css-modules": "^5.0.0"
  }
}
EOF

echo "Creating tsconfig.json..."
cat > "$PROJECT_DIR/tsconfig.json" << 'EOF'
{
"compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "allowJs": true,
    "strict": false,
    "noImplicitAny": false,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "jsx": "react-jsx",
    "outDir": "./dist",
    "rootDir": "./src",
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    },
    "declaration": false,
    "sourceMap": true,
    "incremental": false
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
EOF

echo "Creating vite.config.ts..."
cat > "$PROJECT_DIR/vite.config.ts" << 'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src')
    }
  },
  build: {
    sourcemap: true,
    minify: false,
    rollupOptions: {
      output: {
        manualChunks: {
          'react-vendor': ['react', 'react-dom'],
          'utils': ['lodash', 'axios', 'uuid', 'moment', 'date-fns'],
          'charts': ['chart.js']
        }
      }
    }
  },
  optimizeDeps: {
    include: ['react', 'react-dom', 'lodash', 'axios']
  }
});
EOF

echo "Creating index.html..."
cat > "$PROJECT_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Heavy Project</title>
</head>
<body>
  <div id="root"></div>
  <script type="module" src="/src/main.tsx"></script>
</body>
</html>
EOF

echo "Creating source directory structure..."
mkdir -p "$PROJECT_DIR/src/components"
mkdir -p "$PROJECT_DIR/src/pages"
mkdir -p "$PROJECT_DIR/src/utils"
mkdir -p "$PROJECT_DIR/src/hooks"
mkdir -p "$PROJECT_DIR/src/services"
mkdir -p "$PROJECT_DIR/src/types"
mkdir -p "$PROJECT_DIR/src/contexts"
mkdir -p "$PROJECT_DIR/src/assets"
mkdir -p "$PROJECT_DIR/src/api"

echo "Creating main entry point..."
cat > "$PROJECT_DIR/src/main.tsx" << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root')!);
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

echo "Creating App.tsx..."
cat > "$PROJECT_DIR/src/App.tsx" << 'EOF'
import React from 'react';

const App: React.FC = () => {
  return (
    <div>Heavy Project</div>
  );
};

export default App;
EOF

echo "Generating $NUM_MODULES modules with $NUM_FILES_PER_MODULE files each..."

for i in $(seq 1 $NUM_MODULES); do
    module_dir="$PROJECT_DIR/src/generated/module_$i"
    mkdir -p "$module_dir"
    
    for j in $(seq 1 $NUM_FILES_PER_MODULE); do
        cat > "$module_dir/component_$j.tsx" << EOF
import React, { useState, useEffect } from 'react';

interface Props$i$j {
  data: string[];
}

export const Component$i$j: React.FC<Props$i$j> = ({ data }) => {
  const [state, setState] = useState<number>(0);
  
  useEffect(() => {
    const processed = data.length * 100;
    setState(processed);
  }, [data]);
  
  return (
    <div className="module-$i-component-$j">
      {state}
    </div>
  );
};

export default Component$i$j;
EOF
        
        cat > "$module_dir/utils_$j.ts" << EOF
import _ from 'lodash';

export function processData$j(data: any[]): any {
  return _.groupBy(data, 'type');
}

export function transform$j(obj: Record<string, any>): any {
  return _.mapValues(obj, v => _.pick(v, ['id', 'name']));
}
EOF
        
        cat > "$module_dir/types_$j.ts" << EOF
export interface DataType$i$j {
  id: string;
  name: string;
  value: number;
  timestamp: Date;
  metadata: Record<string, any>;
}

export type Status$i$j = 'pending' | 'active' | 'completed' | 'failed';

export interface Config$i$j {
  enabled: boolean;
  timeout: number;
  retries: number;
}
EOF
    done
    
    if [ $((i % 50)) -eq 0 ]; then
        echo "  Generated $i/$NUM_MODULES modules..."
    fi
done

echo "Creating additional utility files..."
cat > "$PROJECT_DIR/src/utils/helpers.ts" << 'EOF'
import _ from 'lodash';

export const deepClone = <T>(obj: T): T => _.cloneDeep(obj);
export const mergeObjects = <T extends object>(...objs: T[]) => _.merge({}, ...objs);
export const pickProps = <T, K extends keyof T>(obj: T, keys: K[]) => _.pick(obj, keys);
export const omitProps = <T, K extends keyof T>(obj: T, keys: K[]) => _.omit(obj, keys);
EOF

cat > "$PROJECT_DIR/src/utils/api.ts" << 'EOF'
import axios from 'axios';

export const apiClient = axios.create({
  timeout: 10000,
  headers: { 'Content-Type': 'application/json' }
});

export const fetchData = async (url: string) => apiClient.get(url);
export const postData = async (url: string, data: any) => apiClient.post(url, data);
EOF

echo "Project generation complete!"
echo "Location: $PROJECT_DIR"