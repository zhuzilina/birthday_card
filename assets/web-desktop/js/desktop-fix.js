// 桌面版本兼容性修复脚本
(function() {
    'use strict';

    // 检查是否为桌面版本
    const urlParams = new URLSearchParams(window.location.search);
    const isDesktopMode = urlParams.get('desktop') === 'true' || urlParams.get('fullscreen') === 'true';

    if (!isDesktopMode) return;

    // 等待页面完全加载
    function waitForDOMReady() {
        return new Promise((resolve) => {
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', resolve);
            } else {
                resolve();
            }
        });
    }

    // 创建缺失的DOM元素
    function createMissingElements() {
        // 创建缺失的控制面板元素
        const elementsToCreate = [
            { selector: '.controls', id: 'desktop-controls-fallback' },
            { selector: '.menu', id: 'desktop-menu-fallback' },
            { selector: '.canvas-container', id: 'desktop-canvas-container-fallback' },
            { selector: '.stage-container', id: 'desktop-stage-container-fallback' }
        ];

        elementsToCreate.forEach(({ selector, id }) => {
            if (!document.querySelector(selector)) {
                const element = document.createElement('div');
                element.id = id;
                element.className = selector.replace('.', '');
                element.style.display = 'none'; // 隐藏这些fallback元素
                document.body.appendChild(element);
                console.log(`Created fallback element: ${selector}`);
            }
        });
    }

    // 修复appNodes对象
    function fixAppNodes() {
        if (typeof window.appNodes === 'undefined') {
            console.log('appNodes not found, skipping fix');
            return;
        }

        // 为缺失的节点创建fallback
        const fallbackNodes = {
            controls: document.querySelector('.controls') || document.querySelector('#desktop-controls-fallback'),
            menu: document.querySelector('.menu') || document.querySelector('#desktop-menu-fallback'),
            canvasContainer: document.querySelector('.canvas-container') || document.querySelector('#desktop-canvas-container-fallback'),
            stageContainer: document.querySelector('.stage-container') || document.querySelector('#desktop-stage-container-fallback'),
            // 为其他可能缺失的节点创建null fallback
            fullscreenFormOption: document.querySelector('.form-option--fullscreen'),
            finaleModeFormOption: document.querySelector('.form-option--finale-mode'),
            quality: document.querySelector('.quality-ui'),
            shellType: document.querySelector('.shell-type'),
            shellSize: document.querySelector('.shell-size'),
            wordShell: document.querySelector('.word-shell'),
            autoLaunch: document.querySelector('.auto-launch'),
            finaleMode: document.querySelector('.finale-mode'),
            skyLighting: document.querySelector('.sky-lighting'),
            hideControls: document.querySelector('.hide-controls'),
            fullscreen: document.querySelector('.fullscreen'),
            longExposure: document.querySelector('.long-exposure'),
            scaleFactor: document.querySelector('.scaleFactor'),
            menuInnerWrap: document.querySelector('.menu__inner-wrap'),
            helpModal: document.querySelector('.help-modal'),
            helpModalHeader: document.querySelector('.help-modal__header'),
            helpModalBody: document.querySelector('.help-modal__body'),
            helpModalCloseBtn: document.querySelector('.help-modal__close-btn'),
            helpModalOverlay: document.querySelector('.help-modal__overlay')
        };

        // 更新appNodes对象
        Object.keys(fallbackNodes).forEach(key => {
            if (fallbackNodes[key]) {
                window.appNodes[key] = fallbackNodes[key];
            } else {
                // 创建一个空的div作为fallback
                const emptyFallback = document.createElement('div');
                emptyFallback.style.display = 'none';
                emptyFallback.id = `fallback-${key}`;
                document.body.appendChild(emptyFallback);
                window.appNodes[key] = emptyFallback;
                console.log(`Created empty fallback for: ${key}`);
            }
        });
    }

    // 修复renderApp函数
    function fixRenderApp() {
        if (typeof window.renderApp === 'function') {
            const originalRenderApp = window.renderApp;
            window.renderApp = function(state) {
                try {
                    // 检查必要的DOM元素是否存在
                    if (window.appNodes && window.appNodes.controls) {
                        originalRenderApp(state);
                    } else {
                        console.log('Skipping renderApp - missing DOM elements');
                    }
                } catch (error) {
                    console.log('renderApp error handled:', error.message);
                }
            };
        }
    }

    // 修复音频加载问题
    function fixAudioLoading() {
        // 检查是否有直接音频路径数据
        if (window.audioData && Object.keys(window.audioData).length > 0) {
            console.log('Setting up desktop audio loading with direct paths...');

            // 覆盖soundManager的音频加载逻辑
            if (typeof window.soundManager !== 'undefined') {
                const originalPreload = window.soundManager.preload;

                // 创建新的音频加载方法
                window.soundManager.preloadDesktop = function() {
                    console.log('Loading desktop audio files...');
                    const promises = [];

                    // 为每种音频类型加载文件
                    Object.keys(this.audioTypes).forEach(type => {
                        const fileNames = this.audioTypes[type].fileNames;
                        const audioBuffers = [];

                        fileNames.forEach(fileName => {
                            const audioPath = window.audioData[fileName];
                            if (audioPath) {
                                const promise = fetch(audioPath)
                                    .then(response => {
                                        if (!response.ok) {
                                            throw new Error(`HTTP error! status: ${response.status}`);
                                        }
                                        return response.arrayBuffer();
                                    })
                                    .then(data => {
                                        return this.ctx.decodeAudioData(data);
                                    })
                                    .then(audioBuffer => {
                                        audioBuffers.push(audioBuffer);
                                        console.log(`✓ Loaded audio: ${fileName}`);
                                    })
                                    .catch(error => {
                                        console.warn(`Failed to load audio ${fileName}:`, error.message);
                                    });

                                promises.push(promise);
                            }
                        });

                        // 存储音频缓冲区
                        if (audioBuffers.length > 0) {
                            this.buffers[type] = audioBuffers;
                        }
                    });

                    return Promise.all(promises).then(() => {
                        console.log('Desktop audio loading complete');
                        this._browserMode = false; // 禁用浏览器模式，允许播放音频
                    });
                };

                // 替换原始preload方法
                window.soundManager.preload = function() {
                    // 如果有直接音频路径，使用桌面版本加载
                    if (window.useDirectAudioPaths && window.audioData) {
                        return this.preloadDesktop();
                    }
                    // 否则尝试原始方法
                    try {
                        return originalPreload.call(this);
                    } catch (error) {
                        console.log('Audio preload error handled:', error.message);
                        return Promise.resolve();
                    }
                };

                // 修复playSound方法以处理桌面环境
                const originalPlaySound = window.soundManager.playSound;
                window.soundManager.playSound = function(type, scale = 1) {
                    try {
                        // 检查是否为桌面环境且音频已加载
                        if (window.useDirectAudioPaths && this.buffers[type] && this.buffers[type].length > 0) {
                            return originalPlaySound.call(this, type, scale);
                        } else {
                            console.warn(`Audio not available for type: ${type}`);
                        }
                    } catch (error) {
                        console.log(`Play sound error handled:`, error.message);
                    }
                };
            }
        } else {
            // 没有音频数据时的错误处理
            if (typeof window.soundManager !== 'undefined') {
                const originalPreload = window.soundManager.preload;
                window.soundManager.preload = function() {
                    try {
                        return originalPreload.call(this);
                    } catch (error) {
                        console.log('Audio preload error handled:', error.message);
                    }
                };
            }
        }
    }

    // 修复全局错误处理
    function addGlobalErrorHandling() {
        window.addEventListener('error', function(event) {
            if (event.filename && event.filename.includes('script.js')) {
                console.log('Script error handled:', event.error.message);
                event.preventDefault();
                return true;
            }
        });

        window.addEventListener('unhandledrejection', function(event) {
            if (event.reason && event.reason.message && event.reason.message.includes('classList')) {
                console.log('Promise rejection handled:', event.reason.message);
                event.preventDefault();
                return true;
            }
        });
    }

    // 优化性能
    function optimizePerformance() {
        // 降低烟花质量以提高性能
        if (typeof window.store !== 'undefined' && window.store.setState) {
            window.store.setState({
                config: {
                    quality: '1', // 设置为正常质量
                    autoLaunch: true, // 启用自动发射
                    hideControls: true // 隐藏控制面板
                }
            });
        }
    }

    // 主要修复函数
    async function applyDesktopFixes() {
        await waitForDOMReady();

        console.log('Applying desktop version fixes...');

        createMissingElements();

        // 等待原始脚本加载完成
        setTimeout(() => {
            fixAppNodes();
            fixRenderApp();
            fixAudioLoading();
            addGlobalErrorHandling();
            optimizePerformance();

            console.log('Desktop fixes applied successfully');
        }, 2000);
    }

    // 应用修复
    applyDesktopFixes();
})();