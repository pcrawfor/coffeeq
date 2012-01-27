(function() {
  var Ctrl;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; }, __slice = Array.prototype.slice;
  Ctrl = (function() {
    function Ctrl() {
      this.execNextStep = __bind(this.execNextStep, this);
    }
    Ctrl.Step = (function() {
      function Step(func, cont) {
        this.func = func;
        this.cont = cont;
        this.async_started = 0;
        this.async_finished = 0;
        this.a_results = [];
        this.h_results = {};
        this._stop = false;
        this.done = false;
      }
      Step.prototype.execute = function(ctrl) {
        this.func(ctrl);
        if (this.async_started === 0) {
          return this.finished();
        }
      };
      Step.prototype.collect = function() {
        var index, names;
        names = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        index = this.async_started;
        this.async_started += 1;
        return __bind(function() {
          var name, result, results, _i, _len, _ref, _ref2;
          results = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
          if (names.length > 0) {
            _ref = Ctrl.zip(names, results);
            for (_i = 0, _len = _ref.length; _i < _len; _i++) {
              _ref2 = _ref[_i], name = _ref2[0], result = _ref2[1];
              this.h_results[name] = result;
            }
          } else {
            this.a_results[index] = results;
          }
          this.async_finished += 1;
          if (this.async_started === this.async_finished) {
            return this.finished();
          }
        }, this);
      };
      Step.prototype.finished = function() {
        var result, _i, _len, _ref;
        this.results = [];
        _ref = this.a_results;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          result = _ref[_i];
          if (result != null) {
            if (result.length === 1) {
              this.results.push(result[0]);
            } else {
              this.results.push(result);
            }
          }
        }
        this.named_results = this.h_results;
        this.result = this.results[0];
        return this.cont();
      };
      return Step;
    })();
    Ctrl["new"] = function() {
      var ctrl, steps;
      steps = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      ctrl = new Ctrl;
      if (steps.length > 0) {
        ctrl.exec.apply(ctrl, steps);
      }
      return ctrl;
    };
    Ctrl.run = Ctrl["new"];
    Ctrl.zip = function(ar1, ar2) {
      var i, zipped;
      zipped = [];
      i = 0;
      while (i < ar1.length) {
        zipped[i] = [ar1[i], ar2[i]];
        i += 1;
      }
      if (ar2.length > ar1.length) {
        i -= 1;
        zipped[i] = [ar1[i], ar2.slice(i, ar2.length)];
      }
      return zipped;
    };
    Ctrl.prototype.exec = function() {
      var func, funcs;
      funcs = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      this.steps = (function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = funcs.length; _i < _len; _i++) {
          func = funcs[_i];
          _results.push(new Ctrl.Step(func, this.execNextStep));
        }
        return _results;
      }).call(this);
      this.index = -1;
      return this.execNextStep();
    };
    Ctrl.prototype.run = Ctrl.prototype.exec;
    Ctrl.prototype.stop = function() {
      return this._stop = true;
    };
    Ctrl.prototype.currentStep = function() {
      return this.steps[this.index];
    };
    Ctrl.prototype.previousStep = function() {
      return this.steps[this.index - 1];
    };
    Ctrl.prototype.execNextStep = function() {
      var current_step, previous_step;
      this.index += 1;
      previous_step = this.previousStep();
      current_step = this.currentStep();
      if (previous_step != null) {
        this.result = previous_step.result;
        this.results = previous_step.results;
        this.named_results = previous_step.named_results;
      } else {
        this.result = null;
        this.results = [];
        this.named_results = {};
      }
      if ((current_step != null) && !(this._stop != null)) {
        return current_step.execute(this);
      } else {
        return this.done = true;
      }
    };
    Ctrl.prototype.collect = function() {
      var names, _ref;
      names = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return (_ref = this.currentStep()).collect.apply(_ref, names);
    };
    return Ctrl;
  })();
  module.exports = Ctrl;
}).call(this);
