// Grundschrift website: menu toggle and the letter-tracing demo.
// Without JavaScript the menu stays open and every letter is shown fully drawn.
(function () {
  'use strict';

  // ── Menu ────────────────────────────────────────────────────────────────
  var toggle = document.querySelector('.nav-toggle');
  var nav = document.getElementById('hauptmenue');
  if (toggle && nav) {
    var setOpen = function (open) {
      toggle.setAttribute('aria-expanded', String(open));
      nav.classList.toggle('open', open);
    };
    toggle.addEventListener('click', function () {
      setOpen(toggle.getAttribute('aria-expanded') !== 'true');
    });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && toggle.getAttribute('aria-expanded') === 'true') {
        setOpen(false);
        toggle.focus();
      }
    });
  }

  // ── Letter tracing ──────────────────────────────────────────────────────
  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  var SPEED = 520;      // level units per second
  var PAUSE = 450;      // ms between strokes
  var FINGER_TIP = { x: 5, y: 4 }; // fingertip inside the 140×196 finger image

  function Tracer(svg) {
    this.svg = svg;
    this.inks = Array.prototype.slice.call(svg.querySelectorAll('.ink'));
    this.anchors = Array.prototype.slice.call(svg.querySelectorAll('.anchor'));
    this.finger = svg.querySelector('.finger');
    this.lengths = this.inks.map(function (p) { return p.getTotalLength(); });
    this.frame = 0;
  }

  Tracer.prototype.finish = function () {
    cancelAnimationFrame(this.frame);
    this.inks.forEach(function (p) {
      p.style.strokeDasharray = 'none';
      p.style.strokeDashoffset = '0';
    });
    this.anchors.forEach(function (a) { a.classList.add('reached'); });
    this.finger.classList.remove('visible');
  };

  Tracer.prototype.reset = function () {
    var self = this;
    cancelAnimationFrame(this.frame);
    this.inks.forEach(function (p, i) {
      p.style.strokeDasharray = self.lengths[i] + ' ' + self.lengths[i];
      p.style.strokeDashoffset = String(self.lengths[i]);
    });
    this.anchors.forEach(function (a) { a.classList.remove('reached'); });
    this.finger.classList.remove('visible');
  };

  Tracer.prototype.play = function (done) {
    var self = this;
    this.reset();

    // Timeline: each stroke takes length / SPEED seconds, then a short pause.
    var schedule = [];
    var t = 300;
    this.lengths.forEach(function (len) {
      var duration = (len / SPEED) * 1000;
      schedule.push({ start: t, duration: duration });
      t += duration + PAUSE;
    });
    var total = t;
    var started = null;

    function step(now) {
      if (started === null) started = now;
      var elapsed = now - started;
      var active = null;
      schedule.forEach(function (s, i) {
        var progress = Math.min(1, Math.max(0, (elapsed - s.start) / s.duration));
        var eased = progress < 0.5 ? 2 * progress * progress : 1 - Math.pow(-2 * progress + 2, 2) / 2;
        self.inks[i].style.strokeDashoffset = String(self.lengths[i] * (1 - eased));
        self.anchors.forEach(function (a) {
          if (Number(a.dataset.stroke) === i && eased >= Number(a.dataset.at) - 0.001 && progress > 0) {
            a.classList.add('reached');
          }
        });
        if (elapsed >= s.start - 250 && elapsed <= s.start + s.duration) {
          active = { index: i, eased: eased };
        }
      });
      if (active) {
        var point = self.inks[active.index].getPointAtLength(self.lengths[active.index] * active.eased);
        self.finger.setAttribute('x', String(point.x - FINGER_TIP.x));
        self.finger.setAttribute('y', String(point.y - FINGER_TIP.y));
        self.finger.classList.add('visible');
      } else {
        self.finger.classList.remove('visible');
      }
      if (elapsed < total) {
        self.frame = requestAnimationFrame(step);
      } else {
        self.finish();
        if (done) done();
      }
    }
    this.frame = requestAnimationFrame(step);
  };

  function activeSvg(figure) {
    var slots = figure.querySelectorAll('.tracer-slot');
    if (!slots.length) return figure.querySelector('.board-svg');
    for (var i = 0; i < slots.length; i++) {
      if (!slots[i].hidden) return slots[i].querySelector('.board-svg');
    }
    return null;
  }

  function setUp(figure) {
    var tracers = new WeakMap();
    function tracerFor(svg) {
      if (!tracers.has(svg)) tracers.set(svg, new Tracer(svg));
      return tracers.get(svg);
    }
    function play() { tracerFor(activeSvg(figure)).play(); }

    figure.classList.add('ready');
    var replay = figure.querySelector('.replay');
    if (replay) replay.addEventListener('click', play);

    var choices = figure.querySelectorAll('.letter-choice');
    Array.prototype.forEach.call(choices, function (button) {
      button.addEventListener('click', function () {
        var letter = button.dataset.letter;
        Array.prototype.forEach.call(choices, function (b) {
          b.setAttribute('aria-pressed', String(b === button));
        });
        Array.prototype.forEach.call(figure.querySelectorAll('.tracer-slot'), function (slot) {
          var show = slot.dataset.letter === letter;
          slot.hidden = !show;
          var image = slot.querySelector('image[data-href]');
          if (show && image) {
            image.setAttribute('href', image.getAttribute('data-href'));
            image.removeAttribute('data-href');
          }
        });
        var tracer = tracerFor(activeSvg(figure));
        if (reduceMotion.matches) tracer.finish(); else tracer.play();
      });
    });

    if (reduceMotion.matches) {
      tracerFor(activeSvg(figure)).finish();
      return;
    }
    if (figure.dataset.autoplay === 'load') {
      play();
    } else if ('IntersectionObserver' in window) {
      tracerFor(activeSvg(figure)).reset();
      var observer = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            observer.disconnect();
            play();
          }
        });
      }, { threshold: 0.6 });
      observer.observe(figure);
    }
  }

  Array.prototype.forEach.call(document.querySelectorAll('[data-tracer]'), setUp);
})();
