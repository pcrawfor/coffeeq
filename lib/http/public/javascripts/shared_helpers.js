(function(exports) {
    exports.errorLabelClass = function(count) { 
      cssClass = "label";
      if(count > 0) {
        cssClass = cssClass + " important";
      }
      return cssClass;
    } 
    
    exports.queueName = function(queue) {
      var val = queue.replace(":queue:", "");
      return val.charAt(0).toUpperCase() + val.slice(1)
    }
  
    exports.formatTime = function(numMinRunning) {
      var oneDay = 1440;
      var oneHour = 60;
      var currentNumTotal = numMinRunning;
      var days = 0;
      var hours = 0;
      var minutes = 0;
      var dayStr = "0";
      var hourStr = "0";
      var minStr = "0";

      if(numMinRunning > oneDay) {
        days = Math.round(currentNumTotal/oneDay);
        currentNumTotal = currentNumTotal - (days*oneDay);
        if(days < 10) {
          dayStr = "0"+days;
        } else {
          dayStr = days;
        }        
      }

      if(numMinRunning > oneHour) {
        hours = Math.round(currentNumTotal/oneHour);          
        currentNumTotal = currentNumTotal - (hours*oneHour);
        if(hours < 10) {
          hourStr = "0"+hours;
        } else {
          hourStr = hours;
        }
      }

      if(currentNumTotal > 0) {
        minutes = Math.round(currentNumTotal);
      } else {
        minutes = 0;
      }

      if(minutes < 10) {
        minStr = "0"+minutes;
      } else {
        minStr = minutes;
      }           

      return dayStr + " days | " + hourStr + ":" + minStr;
    }

})(typeof exports === 'undefined'? this['shared_helpers']={}: exports);