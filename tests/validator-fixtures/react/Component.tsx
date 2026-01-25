// React component with violations
import React, { useState, useEffect } from 'react';

// N1: dangerouslySetInnerHTML
function BadHTML({ html }) {
  return <div dangerouslySetInnerHTML={{ __html: html }} />;
}

// N2: Index as key
function BadList({ items }) {
  return (
    <ul>
      {items.map((item, index) => (
        <li key={index}>{item}</li>
      ))}
    </ul>
  );
}

// N3: Direct DOM manipulation
function BadDOM() {
  useEffect(() => {
    document.getElementById('root').innerHTML = 'bad';
  }, []);
  return <div />;
}

// M1: Missing dependency array
function BadEffect() {
  const [count, setCount] = useState(0);
  useEffect(() => {
    console.log(count);
  });
  return <div>{count}</div>;
}
