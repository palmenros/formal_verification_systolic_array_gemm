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
    rows: usize,
    cols: usize,
    data: Vec<Vec<T>>,
}

#[derive(Debug)]
pub enum MatrixError {
    InvalidDimensions(String),
    EmptyMatrix,
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

// Implement Display for pretty printing
impl<T: Number> Display for Matrix<T> {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        for (i, row) in self.data.iter().enumerate() {
            let first = i == 0;
            let last = i == self.data.len() - 1;

            let row_string = row.iter()
                .map(|x| format!("{:4}", x))
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
}

