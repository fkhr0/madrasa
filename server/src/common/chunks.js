/** [1..7] in chunks of 3 -> [[1,2,3], [4,5,6], [7]]. For big jobs done in parts. */
function chunks(list, size) {
  const parts = [];
  for (let i = 0; i < list.length; i += size) parts.push(list.slice(i, i + size));
  return parts;
}

module.exports = { chunks };
