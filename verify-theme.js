#!/usr/bin/env node
// =============================================================================
// 验证 index.template.html 里那段主题脚本的三态逻辑。
//
// 做法：把模板里**真实的那段内联脚本**取出来，在一个最小 DOM 桩里跑起来断言。
// 不是抄一份逻辑来测 —— 测的就是页面上会执行的那段代码。
//
// 用法：
//   node verify-theme.js                    # 直接读 index.template.html
//   node verify-theme.js path/to/index.html # 或测构建产物（build/index.html）
//
// 退出码 0 表示全部通过。
//
// 为什么要有它：这段代码连着出过两个 bug（apply() 无条件用系统值把手动选择覆盖掉、
// 三个图标的显隐规则写反导致太阳月亮叠在一起），都是靠断言抓出来的，肉眼看不出来。
// =============================================================================
"use strict";
const fs = require("fs");
const vm = require("vm");
const assert = require("assert");
const path = require("path");

const file = process.argv[2] || path.join(__dirname, "index.template.html");
const HTML = fs.readFileSync(file, "utf8");

// ---------- 取出真实脚本 ----------
const scripts = [...HTML.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
assert.strictEqual(
  scripts.length,
  1,
  `应恰好有 1 段 <script>，实际 ${scripts.length} 段（模板结构变了？）`,
);

// ---------- 最小 DOM 桩 ----------
function makeEnv({ saved = null, systemDark = false } = {}) {
  const store = new Map();
  if (saved !== null) store.set("theme", saved);

  const rootClasses = new Set();
  const root = {
    classList: {
      add: (c) => rootClasses.add(c),
      remove: (c) => rootClasses.delete(c),
      toggle: (c, force) => {
        const on = force === undefined ? !rootClasses.has(c) : !!force;
        if (on) rootClasses.add(c);
        else rootClasses.delete(c);
        return on;
      },
      contains: (c) => rootClasses.has(c),
    },
    style: {},
  };

  const button = {
    dataset: {},
    attrs: {},
    title: "",
    setAttribute(k, v) { this.attrs[k] = String(v); },
    getAttribute(k) { return k in this.attrs ? this.attrs[k] : null; },
  };
  const status = { textContent: "" };

  // 页面里的 apply() 会改写 <meta name="theme-color">
  const mkMeta = (media, content) => ({
    attrs: { media, content },
    getAttribute(k) { return k in this.attrs ? this.attrs[k] : null; },
    setAttribute(k, v) { this.attrs[k] = String(v); },
    removeAttribute(k) { delete this.attrs[k]; },
  });
  const metas = [
    mkMeta("(prefers-color-scheme: light)", "#FFF"),
    mkMeta("(prefers-color-scheme: dark)", "#09090B"),
  ];

  const domReady = [];
  const clickHandlers = [];
  const document = {
    documentElement: root,
    getElementById: (id) =>
      id === "themeToggle" ? button : id === "themeStatus" ? status : null,
    querySelectorAll: (sel) => (sel.includes("theme-color") ? metas : []),
    addEventListener: (type, fn) => {
      if (type === "DOMContentLoaded") domReady.push(fn);
      if (type === "click") clickHandlers.push(fn);
    },
  };

  const mqlListeners = [];
  const mql = {
    matches: systemDark,
    addEventListener: (t, fn) => { if (t === "change") mqlListeners.push(fn); },
    addListener: (fn) => mqlListeners.push(fn),
  };

  const ctx = vm.createContext({
    window: { matchMedia: () => mql },
    document,
    localStorage: {
      getItem: (k) => (store.has(k) ? store.get(k) : null),
      setItem: (k, v) => store.set(k, String(v)),
      removeItem: (k) => store.delete(k),
    },
    console,
  });
  scripts.forEach((s, i) => vm.runInContext(s, ctx, { filename: `inline-${i}.js` }));
  domReady.forEach((fn) => fn());

  return {
    isDark: () => rootClasses.has("dark"),
    colorScheme: () => root.style.colorScheme,
    mode: () => button.dataset.mode,
    label: () => button.getAttribute("aria-label"),
    pressed: () => button.getAttribute("aria-pressed"),
    status: () => status.textContent,
    stored: () => (store.has("theme") ? store.get("theme") : null),
    metaContents: () => metas.map((m) => m.getAttribute("content")),
    metaMedia: () => metas.map((m) => m.getAttribute("media")),
    followSystem(dark) {
      mql.matches = dark;
      mqlListeners.forEach((fn) => fn({ matches: dark }));
    },
    click() {
      const ev = { target: { closest: (sel) => (sel === "#themeToggle" ? button : null) } };
      clickHandlers.forEach((fn) => fn(ev));
    },
  };
}

// ---------- 断言 ----------
let passed = 0;
const t = (name, fn) => {
  try {
    fn();
    passed++;
    console.log(`  ok   ${name}`);
  } catch (e) {
    console.error(`  FAIL ${name}\n       ${e.message}`);
    process.exitCode = 1;
  }
};

console.log(`（待测文件：${file}）`);
console.log("── 首次打开 / 每次刷新：按浏览器主题 ──");
t("没存过选择 + 系统深色 → 深色，模式 auto", () => {
  const e = makeEnv({ systemDark: true });
  assert.strictEqual(e.isDark(), true);
  assert.strictEqual(e.mode(), "auto");
  assert.strictEqual(e.colorScheme(), "dark");
  assert.strictEqual(e.stored(), null, "auto 不应写入 localStorage");
  assert.ok(/自动/.test(e.label()), `label 应说明自动：${e.label()}`);
});
t("没存过选择 + 系统浅色 → 浅色，模式 auto", () => {
  const e = makeEnv({ systemDark: false });
  assert.strictEqual(e.isDark(), false);
  assert.strictEqual(e.mode(), "auto");
  assert.strictEqual(e.pressed(), "false");
});
t("刷新时重新检测：系统变了就跟着变", () => {
  assert.strictEqual(makeEnv({ systemDark: false }).isDark(), false);
  const second = makeEnv({ systemDark: true });
  assert.strictEqual(second.isDark(), true, "第二次刷新应按当前系统主题");
  assert.strictEqual(second.stored(), null, "auto 不写 localStorage，才能一直重测");
});
t("页面开着时系统切换 → 实时跟随", () => {
  const e = makeEnv({ systemDark: false });
  e.followSystem(true);
  assert.strictEqual(e.isDark(), true);
  assert.strictEqual(e.colorScheme(), "dark");
  e.followSystem(false);
  assert.strictEqual(e.isDark(), false);
});
t("系统变化时不写 localStorage（保持自动）", () => {
  const e = makeEnv({ systemDark: false });
  e.followSystem(true);
  assert.strictEqual(e.stored(), null);
});

console.log("── 按钮三态循环 ──");
t("点一下：auto → 浅色（固定）", () => {
  const e = makeEnv({ systemDark: true }); // 系统是深色
  e.click();
  assert.strictEqual(e.mode(), "light");
  assert.strictEqual(e.isDark(), false, "固定浅色应压过系统的深色");
  assert.strictEqual(e.stored(), "light");
  assert.ok(/已固定为浅色/.test(e.status()), `应播报：${e.status()}`);
});
t("再点一下：浅色 → 深色（固定）", () => {
  const e = makeEnv({ systemDark: true });
  e.click();
  e.click();
  assert.strictEqual(e.mode(), "dark");
  assert.strictEqual(e.stored(), "dark");
  assert.strictEqual(e.pressed(), "true");
  assert.ok(/已固定为深色/.test(e.status()));
});
t("第三下回到 auto，并清掉 localStorage 恢复跟随", () => {
  const e = makeEnv({ systemDark: true });
  e.click(); e.click(); e.click();
  assert.strictEqual(e.mode(), "auto");
  assert.strictEqual(e.stored(), null, "auto 必须清掉键，否则刷新后又被固定");
  assert.strictEqual(e.isDark(), true, "回到 auto 应立刻按系统（深色）");
  assert.ok(/已切换到自动/.test(e.status()));
});
t("手动固定后，系统变化不再影响页面", () => {
  const e = makeEnv({ systemDark: false });
  e.click(); // 固定浅色
  e.followSystem(true);
  assert.strictEqual(e.isDark(), false, "固定浅色时系统转深也不该变");
});
t("存过 light → 刷新后仍是浅色（尊重选择）", () => {
  const e = makeEnv({ saved: "light", systemDark: true });
  assert.strictEqual(e.isDark(), false);
  assert.strictEqual(e.mode(), "light");
});
t("存过 dark → 刷新后仍是深色", () => {
  const e = makeEnv({ saved: "dark", systemDark: false });
  assert.strictEqual(e.isDark(), true);
  assert.strictEqual(e.mode(), "dark");
});

console.log("── 地址栏配色 meta ──");
t("深色时 meta 被改成 #09090B 且摘掉 media", () => {
  const e = makeEnv({ systemDark: true });
  assert.strictEqual(e.metaContents()[0], "#09090B");
  assert.strictEqual(e.metaMedia()[0], null, "media 要摘掉，否则手动固定后不生效");
});
t("浅色时 meta 是 #FFF", () => {
  assert.strictEqual(makeEnv({ systemDark: false }).metaContents()[0], "#FFF");
});
t("手动固定浅色后 meta 跟着变（系统仍是深色）", () => {
  const e = makeEnv({ systemDark: true });
  e.click();
  assert.strictEqual(e.metaContents()[0], "#FFF");
});

console.log("── 静态结构 ──");
t("按钮初始 data-mode=auto，label 说明自动", () => {
  const m = HTML.match(/<button[^>]*id="themeToggle"[\s\S]*?>/);
  assert.ok(m, "找不到主题按钮");
  assert.ok(/data-mode="auto"/.test(m[0]), "初始 data-mode 应为 auto");
  assert.ok(/自动/.test(m[0]), "初始 label 应说明自动");
});
t("三个图标都在，且显隐规则是「默认全隐藏只打开一个」", () => {
  for (const c of ["icon-sun", "icon-auto", "icon-moon"]) {
    assert.ok(HTML.includes(`class="${c}"`), `缺少 ${c}`);
  }
  // 关键：基础的 display:none 必须把 .icon-sun 也包含进去（否则深色下会叠图）
  const base = HTML.match(/\.icon-sun,\s*\.icon-auto,\s*\.icon-moon\s*\{[^}]*display:\s*none/);
  assert.ok(base, "基础隐藏规则必须同时包含 .icon-sun/.icon-auto/.icon-moon");
});
t("没有残缺的旧钩子", () => {
  assert.ok(!/localStorage\.setItem\("theme", dark/.test(HTML), "旧的二态写法应已移除");
  assert.ok(!/小圆点/.test(HTML), "已废弃的「小圆点」说明应已清理");
});

console.log(`\n${passed} 项通过${process.exitCode ? "（有失败）" : "，全部通过"}`);
