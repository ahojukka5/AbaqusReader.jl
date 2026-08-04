const { createApp, markRaw } = Vue;

createApp({
    data() {
        return {
            dragging: false,
            loading: false,
            error: null,
            errorDetails: null,
            meshData: null,
            modelData: null,
            fileName: null,
            scene: null,
            camera: null,
            renderer: null,
            controls: null,
            mesh: null,
            solidMesh: null,
            pointsMesh: null,
            apiUrl: window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
                ? 'http://localhost:8080'
                : 'https://abaqusreaderjl-production.up.railway.app',
            connected: false,
            checking: false,
            infoCollapsed: false,
            statusFading: false,
            fadeTimeout: null,
            statusHidden: false,  // Track if status should stay hidden
            showWhy: false,
            showWhyButton: false,
            whyButtonTimeout: null,
            initialLoading: true,
            loadingProgress: 0,
            loadingMessage: 'Initializing...',
            showSlowWarning: false,
            slowWarningTimeout: null,
            testFiles: [],  // Available test files
            selectedTestFile: '',  // Currently selected test file
            showSolid: true,  // Show solid mesh
            showWireframe: false,  // Show wireframe
            showPoints: false  // Show points
        };
    },

    mounted() {
        this.initThreeJS();
        this.startInitialLoading();
        window.addEventListener('resize', this.onWindowResize);
        // Check connection every 5 seconds
        this.connectionInterval = setInterval(() => this.checkConnection(), 5000);
    },

    beforeUnmount() {
        window.removeEventListener('resize', this.onWindowResize);
        if (this.connectionInterval) {
            clearInterval(this.connectionInterval);
        }
        if (this.fadeTimeout) {
            clearTimeout(this.fadeTimeout);
        }
        if (this.whyButtonTimeout) {
            clearTimeout(this.whyButtonTimeout);
        }
        if (this.slowWarningTimeout) {
            clearTimeout(this.slowWarningTimeout);
        }
        if (this.renderer) {
            this.renderer.dispose();
        }
    },

    methods: {
        async startInitialLoading() {
            const startTime = Date.now(); // Track when loading started

            // Set timeout to show warning after 5 seconds
            this.slowWarningTimeout = setTimeout(() => {
                this.showSlowWarning = true;
            }, 5000);

            // Simulate progress from 0 to 100%
            const progressInterval = setInterval(() => {
                if (this.loadingProgress < 95) {
                    this.loadingProgress += Math.random() * 5;
                    if (this.loadingProgress > 95) {
                        this.loadingProgress = 95;
                    }
                }

                // Update loading message based on progress
                if (this.loadingProgress < 30) {
                    this.loadingMessage = 'Initializing...';
                } else if (this.loadingProgress < 60) {
                    this.loadingMessage = 'Connecting to backend...';
                } else if (this.loadingProgress < 95) {
                    this.loadingMessage = 'Waking up Railway backend...';
                }
            }, 100);

            // Try to connect to backend with retries
            const maxRetries = 30; // Up to ~30 seconds
            let retries = 0;
            let connected = false;

            while (retries < maxRetries && !connected) {
                try {
                    const response = await fetch(`${this.apiUrl}/health`, {
                        method: 'GET',
                        mode: 'cors'
                    });

                    if (response.ok) {
                        connected = true;
                        break;
                    }
                } catch (error) {
                    // Backend not ready yet, retry
                }

                retries++;
                await new Promise(resolve => setTimeout(resolve, 1000));
            }

            // Ensure minimum loading time of 10 seconds so users can see the full experience
            const elapsedTime = Date.now() - startTime;
            const minimumLoadingTime = 10000; // 10 seconds
            if (elapsedTime < minimumLoadingTime) {
                await new Promise(resolve => setTimeout(resolve, minimumLoadingTime - elapsedTime));
            }

            // Cleanup and finish loading
            clearInterval(progressInterval);
            clearTimeout(this.slowWarningTimeout);
            this.slowWarningTimeout = null;

            if (connected) {
                this.loadingProgress = 100;
                this.loadingMessage = 'Ready!';

                // Brief pause to show "Ready!" message
                await new Promise(resolve => setTimeout(resolve, 500));

                this.initialLoading = false;

                // Now check connection status for the header indicator
                await this.checkConnection();

                // Fetch available test files
                await this.fetchTestFiles();
            } else {
                // Failed to connect - show error in main UI
                this.initialLoading = false;
                this.connected = false;
                this.connecting = false;
            }
        },

        initThreeJS() {
            const container = this.$refs.canvasContainer;

            // Scene - wrapped with markRaw to prevent Vue reactivity
            this.scene = markRaw(new THREE.Scene());
            this.scene.background = new THREE.Color(0x0a0a0a);  // Very dark background

            // Camera
            this.camera = markRaw(new THREE.PerspectiveCamera(
                75,
                container.clientWidth / container.clientHeight,
                0.1,
                10000
            ));
            this.camera.position.set(50, 50, 50);

            // Renderer
            this.renderer = markRaw(new THREE.WebGLRenderer({ antialias: true }));
            this.renderer.setSize(container.clientWidth, container.clientHeight);
            container.appendChild(this.renderer.domElement);

            // Controls
            this.controls = markRaw(new THREE.OrbitControls(this.camera, this.renderer.domElement));
            this.controls.enableDamping = true;
            this.controls.dampingFactor = 0.05;

            // Lights
            const ambientLight = new THREE.AmbientLight(0xffffff, 0.6);
            this.scene.add(ambientLight);

            const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8);
            directionalLight.position.set(1, 1, 1);
            this.scene.add(directionalLight);

            // Grid (will be resized when mesh is loaded)
            this.gridHelper = new THREE.GridHelper(100, 20, 0x888888, 0xdddddd);
            this.scene.add(this.gridHelper);

            // Axes (will be resized when mesh is loaded)
            this.axesHelper = new THREE.AxesHelper(20);
            this.scene.add(this.axesHelper);

            // Animation loop
            this.animate();
        },

        animate() {
            requestAnimationFrame(this.animate.bind(this));
            this.controls.update();
            this.renderer.render(this.scene, this.camera);
        },

        onWindowResize() {
            const container = this.$refs.canvasContainer;
            this.camera.aspect = container.clientWidth / container.clientHeight;
            this.camera.updateProjectionMatrix();
            this.renderer.setSize(container.clientWidth, container.clientHeight);
        },

        async checkConnection() {
            this.checking = true;

            console.log('Checking connection to:', this.apiUrl + '/health');
            try {
                const controller = new AbortController();
                const timeoutId = setTimeout(() => controller.abort(), 3000);

                const response = await fetch(`${this.apiUrl}/health`, {
                    method: 'GET',
                    signal: controller.signal
                });

                clearTimeout(timeoutId);
                const data = await response.json();
                console.log('Health check response:', data);
                const wasConnected = this.connected;
                this.connected = data.status === 'healthy';
                console.log('Connected:', this.connected);

                // Only show status if connection state changed or it was previously hidden due to error
                if (this.connected && !wasConnected) {
                    // Connection restored - show briefly then fade
                    this.statusFading = false;
                    this.statusHidden = false;
                    if (this.fadeTimeout) {
                        clearTimeout(this.fadeTimeout);
                    }
                    this.fadeTimeout = setTimeout(() => {
                        this.statusFading = true;
                        setTimeout(() => {
                            this.statusHidden = true;
                        }, 1000); // Hide after fade completes
                    }, 3000);
                } else if (this.connected && wasConnected && !this.statusHidden) {
                    // Still connected, first time - fade it
                    if (!this.fadeTimeout) {
                        this.fadeTimeout = setTimeout(() => {
                            this.statusFading = true;
                            setTimeout(() => {
                                this.statusHidden = true;
                            }, 1000);
                        }, 3000);
                    }
                } else if (!this.connected) {
                    // Connection lost - show immediately
                    this.statusFading = false;
                    this.statusHidden = false;
                    if (this.fadeTimeout) {
                        clearTimeout(this.fadeTimeout);
                        this.fadeTimeout = null;
                    }
                }
            } catch (err) {
                console.log('Connection check failed:', err.message);
                this.connected = false;
                // Show status on error
                this.statusFading = false;
                this.statusHidden = false;
                if (this.fadeTimeout) {
                    clearTimeout(this.fadeTimeout);
                    this.fadeTimeout = null;
                }
            } finally {
                this.checking = false;
            }
        },

        async fetchTestFiles() {
            try {
                const response = await fetch(`${this.apiUrl}/testdata/list`);
                const data = await response.json();

                if (data.success && data.files) {
                    this.testFiles = data.files;
                    console.log('Loaded test files:', data.files.length);
                }
            } catch (err) {
                console.log('Could not load test files:', err.message);
                // Not critical, just hide the dropdown
                this.testFiles = [];
            }
        },

        async loadTestFile() {
            if (!this.selectedTestFile) return;

            this.loading = true;
            this.error = null;
            this.fileName = this.selectedTestFile;

            try {
                const response = await fetch(`${this.apiUrl}/testdata/load?file=${encodeURIComponent(this.selectedTestFile)}`);
                const data = await response.json();

                if (data.success) {
                    this.meshData = data;
                    this.modelData = data.model || null;
                    this.visualizeMesh(data);
                } else {
                    this.error = data.error || 'Failed to load test file';
                    this.errorDetails = data.error_details || '';
                }
            } catch (err) {
                this.error = 'Failed to load test file: ' + err.message;
                console.error('Error loading test file:', err);
            } finally {
                this.loading = false;
            }
        },

        formatTestFileName(name) {
            // Remove .inp extension and format nicely
            return name.replace('.inp', '').replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
        },

        handleDrop(e) {
            this.dragging = false;
            e.preventDefault();
            const files = e.dataTransfer?.files;
            if (files && files.length > 0) {
                this.processFile(files[0]);
            }
        },

        handleFileSelect(e) {
            const files = e.target?.files;
            if (files && files.length > 0) {
                this.processFile(files[0]);
            }
        },

        async processFile(file) {
            if (!file.name.endsWith('.inp')) {
                this.error = 'Please select an ABAQUS .inp file';
                return;
            }

            this.fileName = file.name;
            this.loading = true;
            this.error = null;
            this.errorDetails = null;

            try {
                const content = await file.text();
                await this.parseFile(content);
            } catch (err) {
                this.error = 'Failed to read file: ' + err.message;
                this.loading = false;
            }
        },

        async parseFile(content) {
            try {
                const response = await fetch(`${this.apiUrl}/parse`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'text/plain',
                    },
                    body: content
                });

                const data = await response.json();

                if (data.success) {
                    this.meshData = data;
                    this.modelData = data.model || null;
                    // Force Vue to update before visualizing
                    this.$nextTick(() => {
                        this.visualizeMesh(data);
                    });
                } else {
                    this.error = data.error || 'Unknown error occurred';
                    this.errorDetails = data.error_details || null;
                }
            } catch (err) {
                this.error = 'Failed to connect to backend: ' + err.message;
                this.errorDetails = 'Make sure the backend server is running at ' + this.apiUrl;
            } finally {
                this.loading = false;
            }
        },

        visualizeMesh(data) {
            console.log('visualizeMesh called with data:', data);
            console.log('Nodes:', data.nodes.length, 'Elements:', data.elements.length);

            // Remove old meshes
            if (this.mesh) {
                this.scene.remove(this.mesh);
                this.mesh.geometry.dispose();
                this.mesh.material.dispose();
                this.mesh = null;
            }
            if (this.solidMesh) {
                this.scene.remove(this.solidMesh);
                this.solidMesh.geometry.dispose();
                this.solidMesh.material.dispose();
                this.solidMesh = null;
            }
            if (this.pointsMesh) {
                this.scene.remove(this.pointsMesh);
                this.pointsMesh.geometry.dispose();
                this.pointsMesh.material.dispose();
                this.pointsMesh = null;
            }

            const nodes = data.nodes;
            const elements = data.elements;

            if (nodes.length === 0) {
                this.error = 'No nodes found in mesh';
                return;
            }

            console.log('Creating geometry...');

            // Create geometry
            const geometry = new THREE.BufferGeometry();

            // Vertices
            const vertices = [];
            nodes.forEach(node => {
                vertices.push(node[0], node[1], node[2] || 0);
            });
            geometry.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));

            // Edges (wireframe)
            const edges = [];
            const edgeSet = new Set();

            elements.forEach(elem => {
                // Create edges for each element
                for (let i = 0; i < elem.length; i++) {
                    const v1 = elem[i];
                    const v2 = elem[(i + 1) % elem.length];
                    const edge = v1 < v2 ? `${v1}-${v2}` : `${v2}-${v1}`;
                    if (!edgeSet.has(edge)) {
                        edgeSet.add(edge);
                        edges.push(v1, v2);
                    }
                }
            });

            const edgeGeometry = new THREE.BufferGeometry();
            edgeGeometry.setAttribute('position', geometry.getAttribute('position'));
            edgeGeometry.setIndex(edges);

            // Create solid faces with Julia purple material
            const solidMaterial = new THREE.MeshPhongMaterial({
                color: 0x9558B2,  // Julia purple
                side: THREE.DoubleSide,
                flatShading: true,
                opacity: 1.0,
                transparent: false,
                depthWrite: true
            });

            // Create mesh from elements as faces
            const faceIndices = [];
            elements.forEach((elem, idx) => {
                const elemType = data.element_types[idx];
                
                if (elemType === 'Tri3' && elem.length === 3) {
                    // Triangle - add directly
                    faceIndices.push(elem[0], elem[1], elem[2]);
                } else if (elemType === 'Quad4' && elem.length === 4) {
                    // Quad - split into two triangles
                    // Triangle 1: v0, v1, v2
                    faceIndices.push(elem[0], elem[1], elem[2]);
                    // Triangle 2: v0, v2, v3
                    faceIndices.push(elem[0], elem[2], elem[3]);
                } else {
                    // Fallback: fan triangulation for polygons
                    for (let i = 1; i < elem.length - 1; i++) {
                        faceIndices.push(elem[0], elem[i], elem[i + 1]);
                    }
                }
            });

            const faceGeometry = new THREE.BufferGeometry();
            faceGeometry.setAttribute('position', geometry.getAttribute('position'));
            faceGeometry.setIndex(faceIndices);
            faceGeometry.computeVertexNormals();

            const solidMesh = markRaw(new THREE.Mesh(faceGeometry, solidMaterial));
            this.solidMesh = solidMesh;
            this.scene.add(solidMesh);
            console.log('Added solid mesh to scene');

            // Create wireframe edges
            const edgeMaterial = new THREE.LineBasicMaterial({
                color: 0x389826,  // Julia green
                linewidth: 4
            });

            // Create mesh - wrapped with markRaw
            this.mesh = markRaw(new THREE.LineSegments(edgeGeometry, edgeMaterial));
            this.scene.add(this.mesh);
            console.log('Added wireframe to scene');

            // Add points for nodes
            const pointsMaterial = new THREE.PointsMaterial({
                color: 0xCB3C33,  // Julia red
                size: 6,
                sizeAttenuation: false
            });
            const points = markRaw(new THREE.Points(geometry, pointsMaterial));
            this.pointsMesh = points;
            this.scene.add(points);
            console.log('Added points to scene');

            // Set initial visibility based on display mode
            this.updateDisplayMode();

            // Center and fit camera
            geometry.computeBoundingBox();
            const bbox = geometry.boundingBox;
            const center = new THREE.Vector3();
            bbox.getCenter(center);

            const size = new THREE.Vector3();
            bbox.getSize(size);
            const maxDim = Math.max(size.x, size.y, size.z);

            // Update grid to match model size and position
            if (this.gridHelper) {
                this.scene.remove(this.gridHelper);
            }
            const gridSize = maxDim * 2; // Make grid 2x the model size
            const gridDivisions = Math.max(10, Math.floor(gridSize / 10));
            this.gridHelper = new THREE.GridHelper(gridSize, gridDivisions, 0x888888, 0x444444);
            this.gridHelper.position.set(center.x, bbox.min.y, center.z);
            this.scene.add(this.gridHelper);

            // Update axes to match model scale
            if (this.axesHelper) {
                this.scene.remove(this.axesHelper);
            }
            this.axesHelper = new THREE.AxesHelper(maxDim * 0.5);
            this.axesHelper.position.copy(center);
            this.scene.add(this.axesHelper);

            this.camera.position.set(
                center.x + maxDim * 1.5,
                center.y + maxDim * 1.5,
                center.z + maxDim * 1.5
            );

            this.controls.target.copy(center);
            this.controls.update();

            // Force immediate render
            console.log('Forcing render...');
            this.renderer.render(this.scene, this.camera);
            console.log('Render complete!');

            // Show "Why?" button after 5 seconds
            if (this.whyButtonTimeout) {
                clearTimeout(this.whyButtonTimeout);
            }
            this.whyButtonTimeout = setTimeout(() => {
                this.showWhyButton = true;
            }, 5000);
        },

        reset() {
            this.meshData = null;
            this.modelData = null;
            this.fileName = null;
            this.error = null;
            this.errorDetails = null;
            this.showWhyButton = false;

            if (this.whyButtonTimeout) {
                clearTimeout(this.whyButtonTimeout);
                this.whyButtonTimeout = null;
            }

            // Remove all mesh objects
            if (this.mesh) {
                this.scene.remove(this.mesh);
                this.mesh.geometry.dispose();
                this.mesh.material.dispose();
                this.mesh = null;
            }
            if (this.solidMesh) {
                this.scene.remove(this.solidMesh);
                this.solidMesh.geometry.dispose();
                this.solidMesh.material.dispose();
                this.solidMesh = null;
            }
            if (this.pointsMesh) {
                this.scene.remove(this.pointsMesh);
                this.pointsMesh.geometry.dispose();
                this.pointsMesh.material.dispose();
                this.pointsMesh = null;
            }
        },

        reportIssue() {
            const title = encodeURIComponent(`Parsing error: ${this.fileName || 'Unknown file'}`);
            const body = encodeURIComponent(
                `## Problem\n\nFailed to parse ABAQUS input file.\n\n` +
                `**File:** ${this.fileName}\n\n` +
                `**Error:** ${this.error}\n\n` +
                `## Steps to Reproduce\n\n` +
                `1. Upload the attached .inp file to the online visualizer\n` +
                `2. Parsing fails with the error above\n\n` +
                `## Additional Context\n\n` +
                `Please attach your .inp file to help us fix this issue.\n`
            );
            window.open(
                `https://github.com/ahojukka5/AbaqusReader.jl/issues/new?title=${title}&body=${body}`,
                '_blank'
            );
        },

        showWhyDialog() {
            this.showWhy = true;
        },

        updateDisplayMode() {
            if (this.solidMesh) {
                this.solidMesh.visible = this.showSolid;
            }
            if (this.mesh) {
                this.mesh.visible = this.showWireframe;
            }
            if (this.pointsMesh) {
                this.pointsMesh.visible = this.showPoints;
            }
        }
    }
}).mount('#app');
