use std::fmt;
use std::fmt::{Debug, Display};
use std::ops::{Add, AddAssign, Mul, MulAssign};

// Trait to identify types that can represent elements of a matrix
pub trait Number: Copy + Default + Add<Output=Self> + AddAssign + Mul<Output=Self> + MulAssign + Display + Debug + PartialEq {}

// Actually implement the trait for common integral types
impl Number for f32 {}
impl Number for f64 {}
impl Number for i8 {}
impl Number for i16 {}
impl Number for i32 {}
impl Number for i64 {}
impl Number for u8 {}
impl Number for u16 {}
impl Number for u32 {}
impl Number for u64 {}

#[derive(Debug, Clone, PartialEq)]
pub struct Matrix<T: Number> {
    pub rows: usize,
    pub cols: usize,
    pub data: Vec<Vec<T>>,
}

#[derive(Debug)]
pub enum MatrixError {
    InvalidDimensions(String),
    EmptyMatrix,
}

// A structure that represents a matrix split into different tilees, each of size tile_size x tile_size
#[derive(Debug)]
pub struct TiledMatrix<T: Number> {
    pub tiles: Vec<Vec<Matrix<T>>>,
    pub tile_size: usize,
}

impl<T: Number> Matrix<T> {
    /// Creates a new matrix from a 2D vector
    pub fn new(data: Vec<Vec<T>>) -> Result<Self, MatrixError> {
        if data.is_empty() || data[0].is_empty() {
            return Err(MatrixError::EmptyMatrix);
        }

        let rows = data.len();
        let cols = data[0].len();

        // Verify all rows have the same length
        if !data.iter().all(|row| row.len() == cols) {
            return Err(MatrixError::InvalidDimensions(
                "All rows must have the same length".to_string(),
            ));
        }

        Ok(Matrix { rows, cols, data })
    }

    /// Creates a zero matrix of specified dimensions
    pub fn zeros(rows: usize, cols: usize) -> Result<Self, MatrixError> {
        if rows == 0 || cols == 0 {
            return Err(MatrixError::InvalidDimensions(
                "Dimensions must be positive".to_string(),
            ));
        }
        Ok(Matrix {
            rows,
            cols,
            data: vec![vec![T::default(); cols]; rows],
        })
    }

    /// Returns the dimensions of the matrix
    pub fn dimensions(&self) -> (usize, usize) {
        (self.rows, self.cols)
    }

    /// Returns a reference to the underlying data
    pub fn data(&self) -> &Vec<Vec<T>> {
        &self.data
    }

    /// Splits the matrix into tiles of the specified size
    /// Returns a new matrix where each element is itself a matrix (tile) of size tile_size x tile_size.
    pub fn split_into_tiles(&self, tile_size: usize) -> Result<TiledMatrix<T>, MatrixError> {
        if tile_size == 0 {
            return Err(MatrixError::InvalidDimensions(
                "Tile size must be positive".to_string(),
            ));
        }

        // Check if matrix dimensions are divisible by tile_size
        if self.rows % tile_size != 0 || self.cols % tile_size != 0 {
            return Err(MatrixError::InvalidDimensions(
                "Matrix dimensions must be divisible by tile size".to_string(),
            ));
        }

        let tile_rows = self.rows / tile_size;
        let tile_cols = self.cols / tile_size;
        let mut tiles = Vec::with_capacity(tile_rows);

        // Create tiles
        for i in 0..tile_rows {
            let mut tile_row = Vec::with_capacity(tile_cols);
            for j in 0..tile_cols {
                // Extract data for this tile
                let mut tile_data = Vec::with_capacity(tile_size);
                for ti in 0..tile_size {
                    let row_idx = i * tile_size + ti;
                    let mut row = Vec::with_capacity(tile_size);
                    for tj in 0..tile_size {
                        let col_idx = j * tile_size + tj;
                        row.push(self.data[row_idx][col_idx]);
                    }
                    tile_data.push(row);
                }
                tile_row.push(Matrix::new(tile_data)?);
            }
            tiles.push(tile_row);
        }

        Ok(TiledMatrix { tiles, tile_size })
    }
}

// Implement matrix multiplication using the Mul trait
impl<T: Number> Mul for &Matrix<T> {
    type Output = Result<Matrix<T>, MatrixError>;

    fn mul(self, rhs: &Matrix<T>) -> Self::Output {
        // Check dimensions for multiplication
        if self.cols != rhs.rows {
            return Err(MatrixError::InvalidDimensions(format!(
                "Cannot multiply {}x{} matrix with {}x{} matrix",
                self.rows, self.cols, rhs.rows, rhs.cols
            )));
        }

        // Create a new matrix to store the results
        let mut result = Matrix::zeros(self.rows, rhs.cols)?;

        // Actually multiply the matrices
        for i in 0..self.rows {
            for j in 0..rhs.cols {
                for k in 0..self.cols {
                    result.data[i][j] += self.data[i][k] * rhs.data[k][j];
                }
            }
        }

        Ok(result)
    }
}


// Implement matrix multiplication using the Add trait
impl<T: Number> Add for &Matrix<T> {
    type Output = Result<Matrix<T>, MatrixError>;

    fn add(self, rhs: Self) -> Self::Output {
        // Check if matrices have the same dimensions
        if self.rows != rhs.rows || self.cols != rhs.cols {
            return Err(MatrixError::InvalidDimensions(format!(
                "Cannot add {}x{} matrix with {}x{} matrix",
                self.rows, self.cols, rhs.rows, rhs.cols
            )));
        }

        // Create a new matrix to store the result
        let mut result = Matrix::zeros(self.rows, self.cols)?;

        // Add corresponding elements
        for i in 0..self.rows {
            for j in 0..self.cols {
                result.data[i][j] = self.data[i][j] + rhs.data[i][j];
            }
        }

        Ok(result)
    }
}

// Implement Display for pretty printing matrices
impl<T: Number> Display for Matrix<T> {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        // Calculate the width needed for each element
        let max_width = self.data.iter()
            .flat_map(|row| row.iter())
            .map(|x| format!("{}", x).len())
            .max()
            .unwrap()
            .max(2);

        for (i, row) in self.data.iter().enumerate() {
            let first = i == 0;
            let last = i == self.data.len() - 1;

            let row_string = row.iter()
                .map(|x| format!("{:>width$}", x, width = max_width))
                .collect::<Vec<_>>()
                .join(",");

            match (first, last) {
                (false, false) => writeln!(f, " [{}],", row_string),
                (true, false) => writeln!(f, "[[{}],", row_string),
                (false, true) => writeln!(f, " [{}]]", row_string),
                (true, true) => writeln!(f, "[[{}]]", row_string),
            }?
        }
        Ok(())
    }
}

// Implement Display for pretty printing tiled matrices
impl<T: Number> Display for TiledMatrix<T> {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        let tile_rows = self.tiles.len();
        let tile_cols = self.tiles[0].len();

        // Calculate the width needed for each element
        let max_width = self.tiles.iter()
            .flat_map(|row| row.iter())
            .flat_map(|tile| tile.data.iter())
            .flat_map(|row| row.iter())
            .map(|x| format!("{}", x).len())
            .max()
            .unwrap()
            .max(2);

        // Helper function to draw horizontal separators
        let draw_separator = |f: &mut fmt::Formatter, is_double: bool| -> fmt::Result {
            for tc in 0..tile_cols {
                if tc == 0 {
                    write!(f, "+")?;
                }
                for _ in 0..((1 + max_width) * self.tile_size) {
                    write!(f, "{}", if is_double { "=" } else { "-" })?;
                }
                write!(f, "+")?;
            }
            writeln!(f)
        };

        // Draw the matrix with tile separators
        for tr in 0..tile_rows {
            // Draw horizontal separator between tiles
            if tr == 0 {
                draw_separator(f, true)?;
            } else {
                draw_separator(f, false)?;
            }

            // Draw rows within each tile
            for row_within_tile in 0..self.tile_size {
                write!(f, "|")?;
                for tc in 0..tile_cols {
                    // Print each element in the row
                    for col_within_tile in 0..self.tile_size {
                        let val = self.tiles[tr][tc].data[row_within_tile][col_within_tile];
                        write!(f, " {:>width$}", val, width = max_width)?;
                    }
                    write!(f, "|")?;
                }
                writeln!(f)?;
            }
        }

        // Draw final separator
        draw_separator(f, true)?;

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_integer_matrix_multiplication() -> Result<(), MatrixError> {
        let lhs: Matrix<i32> = Matrix::new(vec![
            vec![1, 2, 3],
            vec![4, 5, 6],
        ])?;

        let rhs = Matrix::new(vec![
            vec![7, 8],
            vec![9, 10],
            vec![11, 12]
        ])?;

        let result = (&lhs * &rhs)?;
        let expected = Matrix::new(vec![
            vec![58, 64],
            vec![139, 154],
        ])?;

        assert_eq!(result, expected);
        Ok(())
    }

    #[test]
    fn test_integer_matrix_addition() -> Result<(), MatrixError> {
        let lhs: Matrix<i32> = Matrix::new(vec![
            vec![1, 2, 3],
            vec![4, 5, 6],
        ])?;

        let rhs = Matrix::new(vec![
            vec![7, 8, 9],
            vec![10, 11, 12],
        ])?;

        let result = (&lhs + &rhs)?;

        let expected = Matrix::new(vec![
            vec![8, 10, 12],
            vec![14, 16, 18],
        ])?;

        assert_eq!(result, expected);
        Ok(())
    }

    #[test]
    fn test_matrix_tiling() -> Result<(), MatrixError> {
        let matrix = Matrix::new(vec![
            vec![1, 2, 3, 4],
            vec![5, 6, 7, 8],
            vec![9, 10, 11, 12],
            vec![13, 14, 15, 16],
        ])?;

        let tiled_matrix = matrix.split_into_tiles(2)?;

        // println!("{tiled_matrix}");
        //
        // for i in 0..tiled_matrix.tiles.len() {
        //     for j in 0..tiled_matrix.tiles[0].len() {
        //         println!("{}", tiled_matrix.tiles[i][j])
        //     }
        // }

        // Check dimensions
        assert_eq!(tiled_matrix.tiles.len(), 2);
        assert_eq!(tiled_matrix.tiles[0].len(), 2);

        let expected_tiles = vec![
            vec![
                Matrix::new(vec![
                    vec![1, 2],
                    vec![5, 6],
                ])?,
                Matrix::new(vec![
                    vec![3, 4],
                    vec![7, 8],
                ])?
            ],
            vec![
                Matrix::new(vec![
                    vec![9, 10],
                    vec![13, 14],
                ])?,
                Matrix::new(vec![
                    vec![11, 12],
                    vec![15, 16],
                ])?,
            ]
        ];

        assert_eq!(tiled_matrix.tiles, expected_tiles);

        Ok(())
    }
}

