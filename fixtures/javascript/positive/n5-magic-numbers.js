// N5: Magic Number Calculations
// These SHOULD trigger violations
// Pattern: chained binary_expression with * operator (3+ numbers multiplied)

// Time calculations - violations
const millisecondsPerHour = 60 * 60 * 1000;
const secondsPerDay = 24 * 60 * 60;
const millisecondsPerDay = 24 * 60 * 60 * 1000;
const millisecondsPerWeek = 7 * 24 * 60 * 60 * 1000;

// Size calculations - violations
const bytesPerMegabyte = 1024 * 1024 * 1;
const kilobytesPerGigabyte = 1024 * 1024 * 1024;

// In function call - violation
setTimeout(callback, 60 * 60 * 1000);

// In assignment - violation
const cacheExpiry = 30 * 24 * 60 * 60 * 1000;

// Valid code (no violations) - pre-calculated constants
const MS_PER_HOUR = 3600000;
const SECONDS_PER_DAY = 86400;
const MS_PER_DAY = 86400000;
const MS_PER_WEEK = 604800000;

// Valid - only two numbers multiplied (not chained)
const twoNumbers = 60 * 1000;
const simpleCalc = 24 * 60;

// Valid - using named constants
const HOURS_PER_DAY = 24;
const MINUTES_PER_HOUR = 60;
